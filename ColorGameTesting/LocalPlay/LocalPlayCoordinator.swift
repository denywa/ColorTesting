import Foundation
import Observation

@MainActor
@Observable
final class LocalPlayCoordinator {
    private(set) var mode: PlayMode = .singleDevice
    private(set) var role: SessionRole?
    private(set) var session: SessionState?
    private(set) var sessionID: UUID?
    private(set) var discoveredSessions: [DiscoveredSession] = []
    private(set) var connectionStatus: SessionStatus = .waiting
    private(set) var error: LocalPlayError?
    private(set) var latestSnapshot: GameSnapshot?

    private let viewModel: GameViewModel
    private let transport: any LocalPeerTransport
    private let clientID = UUID()
    private var reconnectToken: UUID?
    private var hostPeer: PeerHandle?
    private var peersByRole: [SessionRole: PeerHandle] = [:]
    private var pendingPeers: Set<PeerHandle> = []
    private var acceptedActionIDs: Set<UUID> = []
    private var assignmentHistory: [Int: [PlayerID: PlayerAssignment]] = [:]
    private var historyRoundID: UUID?
    private let snapshotMapper = LocalGameSnapshotMapper()
    private var welcomedPeers: Set<PeerHandle> = []
    private var outboundTasks: [PeerHandle: Task<Void, Never>] = [:]

    init(viewModel: GameViewModel, transport: any LocalPeerTransport) {
        self.viewModel = viewModel
        self.transport = transport
        transport.onEvent = { [weak self] event in self?.handle(event) }
    }

    var canStartRound: Bool {
        role == .host && session?.seats.count == 3 &&
        session?.seats.allSatisfy { $0.status == .connected } == true
    }

    var seatStatus: [GameSnapshot.SeatStatus] {
        if role == .host {
            return session?.seats.map { .init(player: $0.role.playerID, status: $0.status) } ?? []
        }
        return latestSnapshot?.seatStatus ?? []
    }

    var paused: Bool { role == .host ? session?.paused ?? false : latestSnapshot?.paused ?? false }

    func chooseMode(_ mode: PlayMode) { self.mode = mode }

    func startHosting(serviceName: String = "ColorGame") throws {
        let id = UUID()
        let initial = try SessionState(sessionID: id, seats: [
            SessionSeat(role: .host, clientID: clientID, reconnectToken: nil, status: .connected)
        ], paused: false, snapshotRevision: 0)
        mode = .threeDevices
        role = .host
        sessionID = id
        session = initial
        connectionStatus = .connected
        error = nil
        acceptedActionIDs.removeAll()
        assignmentHistory.removeAll()
        historyRoundID = nil
        welcomedPeers.removeAll()
        outboundTasks.removeAll()
        latestSnapshot = nil
        viewModel.configureLocalPlay(localPlayer: .player1, isHost: true) { [weak self] _, slot in
            self?.performLocalColor(slot)
        }
        viewModel.didChange = { [weak self] in
            self?.recordAssignment()
            self?.publishChange()
        }
        defer { transport.startHeartbeats(sessionID: id) }
        do { try transport.host(serviceName: serviceName) }
        catch {
            self.error = error as? LocalPlayError ?? .wifiUnavailable
            connectionStatus = .disconnected
            throw error
        }
    }

    func startBrowsing() {
        mode = .threeDevices
        discoveredSessions = []
        error = nil
        transport.browse()
    }

    func join(_ discovered: DiscoveredSession) {
        mode = .threeDevices
        error = nil
        connectionStatus = .waiting
        transport.connect(discovered)
    }

    func handle(_ event: TransportEvent) {
        switch event {
        case .discovered(let discovered):
            if let index = discoveredSessions.firstIndex(where: { $0.name == discovered.name }) {
                discoveredSessions[index] = discovered
            } else {
                discoveredSessions.append(discovered)
            }
        case .connected(let peer):
            if role == .host {
                connectionStatus = .connected
                error = nil
                pendingPeers.insert(peer)
            } else {
                hostPeer = peer
                let hello = WireMessage.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                     clientID: clientID, sessionID: sessionID,
                                                     reconnectToken: reconnectToken))
                Task { [weak self] in
                    guard let self else { return }
                    do { try await self.transport.send(hello, to: peer) }
                    catch { self.error = error as? LocalPlayError ?? .disconnected }
                }
            }
        case .disconnected(let peer):
            pendingPeers.remove(peer)
            welcomedPeers.remove(peer)
            outboundTasks.removeValue(forKey: peer)
            if role == .host, let assigned = peersByRole.first(where: { $0.value == peer })?.key {
                peersByRole.removeValue(forKey: assigned)
                updateSeat(assigned, status: .disconnected)
            } else if hostPeer == peer {
                hostPeer = nil
                connectionStatus = .disconnected
            }
        case .received(let message, let peer):
            if role == .host {
                if case .hello(let hello) = message { accept(hello, from: peer) }
                else if case .input(let input) = message {
                    if let assigned = peersByRole.first(where: { $0.value == peer })?.key {
                        _ = acceptInput(input, from: assigned)
                    }
                }
                else if case .heartbeat = message { break }
                else { reject(.invalidMessage, peer: peer) }
            } else if peer == hostPeer {
                switch message {
                case .welcome(let welcome):
                    guard sessionID == nil || sessionID == welcome.sessionID,
                          role == nil || role == welcome.role else {
                        error = .invalidSession
                        transport.disconnect(peer)
                        transport.browse()
                        return
                    }
                    sessionID = welcome.sessionID
                    role = welcome.role
                    reconnectToken = welcome.reconnectToken
                    connectionStatus = .connected
                    viewModel.configureLocalPlay(localPlayer: welcome.role.playerID, isHost: false) { [weak self] _, slot in
                        self?.performLocalColor(slot)
                    }
                    transport.startHeartbeats(sessionID: welcome.sessionID)
                case .reject(let rejection):
                    error = rejection.reason
                    transport.disconnect(peer)
                    transport.browse()
                case .snapshot(let snapshot):
                    guard sessionID == snapshot.sessionID,
                          snapshot.snapshotRevision > (latestSnapshot?.snapshotRevision ?? -1),
                          connectionStatus == .connected else { return }
                    do {
                        try snapshotMapper.apply(snapshot, to: viewModel)
                        latestSnapshot = snapshot
                    } catch {
                        self.error = error as? LocalPlayError ?? .invalidMessage
                        transport.disconnect(peer)
                    }
                default: break
                }
            }
        case .failure(let failure):
            error = failure
        }
    }

    private func recordAssignment() {
        guard role == .host else { return }
        if historyRoundID != viewModel.roundID {
            historyRoundID = viewModel.roundID
            assignmentHistory.removeAll()
            acceptedActionIDs.removeAll()
        }
        guard let epoch = viewModel.assignmentEpoch,
              let assignments = viewModel.round?.assignments,
              assignments.count == PlayerID.allCases.count else { return }
        if assignmentHistory[epoch] == nil { assignmentHistory[epoch] = assignments }
    }

    private func publishChange() {
        guard role == .host, var current = session else { return }
        current.snapshotRevision += 1
        session = current
        broadcastSnapshot()
    }

    private func broadcastSnapshot() {
        guard let session else { return }
        do {
            let snapshot = try snapshotMapper.makeSnapshot(from: viewModel, session: session)
            latestSnapshot = snapshot
            for peer in welcomedPeers { enqueue(.snapshot(snapshot), to: peer) }
        } catch {
            self.error = error as? LocalPlayError ?? .invalidMessage
        }
    }

    private func enqueue(_ message: WireMessage, to peer: PeerHandle,
                         afterSend: (() -> Void)? = nil) {
        let previous = outboundTasks[peer]
        outboundTasks[peer] = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                try await self.transport.send(message, to: peer)
                afterSend?()
            } catch {
                self.error = error as? LocalPlayError ?? .disconnected
                self.transport.disconnect(peer)
            }
        }
    }

    func setPaused(_ paused: Bool) {
        guard role == .host, viewModel.phase != .settings,
              var current = session, current.paused != paused else { return }
        current.paused = paused
        session = current
        if paused { viewModel.pauseTimer() } else { viewModel.resumeTimer() }
        publishChange()
    }

    private func performLocalColor(_ slot: ColorSlot) {
        guard let role, let assignment = viewModel.round?.assignments[role.playerID],
              let epoch = viewModel.assignmentEpoch else { return }
        let color = slot == .primary ? assignment.primaryColor : assignment.secondaryColor
        perform(.addColor(slot: slot, observedColorID: color.id, assignmentEpoch: epoch))
    }

    @discardableResult
    func perform(_ action: LocalGameAction) -> Bool {
        guard let role, let sessionID,
              let roundID = viewModel.roundID, viewModel.phase == .playing,
              viewModel.round?.mix.isLocked == false,
              connectionStatus == .connected else { return false }
        guard case let .addColor(slot, observedColorID, epoch) = action,
              epoch == viewModel.assignmentEpoch,
              let assignment = viewModel.round?.assignments[role.playerID],
              (slot == .primary ? assignment.primaryColor.id : assignment.secondaryColor.id) == observedColorID else {
            return false
        }
        let input = WireMessage.Input(sessionID: sessionID, roundID: roundID,
                                      actionID: UUID(), action: action)
        if role == .host { return acceptInput(input, from: .host) }
        guard let hostPeer else { return false }
        Task { [weak self] in
            guard let self else { return }
            do { try await self.transport.send(.input(input), to: hostPeer) }
            catch { self.error = error as? LocalPlayError ?? .disconnected }
        }
        return true
    }

    private func acceptInput(_ input: WireMessage.Input, from source: SessionRole) -> Bool {
        guard role == .host, let session,
              input.sessionID == session.sessionID,
              input.roundID == viewModel.roundID,
              session.seats.count == PlayerID.allCases.count,
              session.seats.allSatisfy({ $0.status == .connected }),
              !session.paused, viewModel.phase == .playing,
              viewModel.round?.mix.isLocked == false,
              !acceptedActionIDs.contains(input.actionID),
              case let .addColor(slot, observedColorID, epoch) = input.action,
              let assignment = assignmentHistory[epoch]?[source.playerID] else { return false }
        let color = slot == .primary ? assignment.primaryColor : assignment.secondaryColor
        guard color.id == observedColorID,
              viewModel.acceptColor(color, for: source.playerID) else { return false }
        acceptedActionIDs.insert(input.actionID)
        return true
    }

    private func accept(_ hello: WireMessage.Hello, from peer: PeerHandle) {
        guard pendingPeers.contains(peer) else { return }
        guard hello.protocolVersion == LocalPlayProtocol.version else {
            reject(.versionMismatch, peer: peer)
            return
        }
        guard let current = session else { return }
        let assigned: SessionRole
        let token: UUID
        if let reconnectToken = hello.reconnectToken {
            guard hello.sessionID == current.sessionID,
                  let seat = current.seats.first(where: {
                      $0.clientID == hello.clientID && $0.reconnectToken == reconnectToken
                  }) else {
                reject(.invalidSession, peer: peer)
                return
            }
            assigned = seat.role
            token = reconnectToken
        } else {
            guard hello.sessionID == nil,
                  !current.seats.contains(where: { $0.clientID == hello.clientID }) else {
                reject(.invalidSession, peer: peer)
                return
            }
            guard let free = [SessionRole.player2, .player3].first(where: { candidate in
                !current.seats.contains(where: { $0.role == candidate })
            }) else {
                reject(.sessionFull, peer: peer)
                return
            }
            assigned = free
            token = UUID()
            let seat = SessionSeat(role: assigned, clientID: hello.clientID,
                                   reconnectToken: token, status: .connected)
            session = try! SessionState(sessionID: current.sessionID, seats: current.seats + [seat],
                                        paused: current.paused,
                                        snapshotRevision: current.snapshotRevision + 1)
            broadcastSnapshot()
        }
        if let stale = peersByRole[assigned], stale != peer {
            peersByRole[assigned] = peer
            transport.disconnect(stale)
        } else {
            peersByRole[assigned] = peer
        }
        pendingPeers.remove(peer)
        updateSeat(assigned, status: .connected)
        let welcome = WireMessage.welcome(.init(sessionID: current.sessionID,
                                                role: assigned, reconnectToken: token))
        enqueue(welcome, to: peer) { [weak self] in
            guard let self, self.peersByRole[assigned] == peer else { return }
            self.welcomedPeers.insert(peer)
            if let session = self.session,
               let snapshot = try? self.snapshotMapper.makeSnapshot(from: self.viewModel, session: session) {
                self.enqueue(.snapshot(snapshot), to: peer)
            }
        }
    }

    private func updateSeat(_ role: SessionRole, status: SessionStatus) {
        guard let current = session,
              let index = current.seats.firstIndex(where: { $0.role == role }),
              current.seats[index].status != status else { return }
        var seats = current.seats
        seats[index].status = status
        session = try! SessionState(sessionID: current.sessionID, seats: seats,
                                    paused: current.paused,
                                    snapshotRevision: current.snapshotRevision + 1)
        broadcastSnapshot()
    }

    private func reject(_ reason: LocalPlayError, peer: PeerHandle) {
        guard let sessionID else { return }
        pendingPeers.remove(peer)
        Task { [weak self] in
            guard let self else { return }
            try? await self.transport.send(.reject(.init(sessionID: sessionID, reason: reason)), to: peer)
            self.transport.disconnect(peer)
        }
    }
}
