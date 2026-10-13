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
    private(set) var voting: LocalVotingState?

    private let viewModel: GameViewModel
    private let transport: any LocalPeerTransport
    private var clientID = UUID()
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
    private var hostIsForeground = true
    private var pauseRequested = false
    private var awaitingSnapshot = false
    private var recoveringPeers: [SessionRole: (peer: PeerHandle, attempt: UUID)] = [:]
    private var endingSession = false

    init(viewModel: GameViewModel, transport: any LocalPeerTransport) {
        self.viewModel = viewModel
        self.transport = transport
        transport.onEvent = { [weak self] event in self?.handle(event) }
    }

    isolated deinit {
        transport.stop()
    }

    var canStartRound: Bool {
        role == .host && hostIsForeground && connectionStatus == .connected &&
        viewModel.phase == .settings && viewModel.canConfirm &&
        (1...3600).contains(viewModel.reassignmentDuration) &&
        (viewModel.selectedRequestID == nil ||
         viewModel.availableRequests.contains { $0.id == viewModel.selectedRequestID }) &&
        session?.paused == false && session?.seats.count == 3 &&
        session?.seats.allSatisfy { $0.status == .connected } == true
    }

    var canStartRun: Bool {
        role == .host && hostIsForeground && connectionStatus == .connected &&
        recoveringPeers.isEmpty && viewModel.canStartRun && (1...3600).contains(viewModel.reassignmentDuration) &&
        session?.paused == false && session?.seats.count == 3 &&
        session?.seats.allSatisfy { $0.status == .connected } == true
    }

    var seatStatus: [GameSnapshot.SeatStatus] {
        if role == .host {
            return session?.seats.map { .init(player: $0.role.playerID, status: $0.status) } ?? []
        }
        return latestSnapshot?.seatStatus ?? []
    }

    var paused: Bool {
        if role == .host { return session?.paused ?? false }
        return role != nil && (awaitingSnapshot || connectionStatus != .connected || latestSnapshot?.paused == true)
    }

    func chooseMode(_ mode: PlayMode) { self.mode = mode }

    func leaveSession() async {
        guard !endingSession else { return }
        endingSession = true
        viewModel.pauseSessionClocks()
        viewModel.didChange = nil
        if role == .host, let sessionID {
            for task in Array(outboundTasks.values) { await task.value }
            guard self.sessionID == sessionID else { return }
            let end = WireMessage.end(.init(sessionID: sessionID, reason: .hostEnded))
            for peer in Set(peersByRole.values) {
                guard self.sessionID == sessionID else { return }
                try? await transport.send(end, to: peer)
            }
        }
        finishSession()
    }

    func appWillTerminate() {
        finishSession()
    }

    private func finishSession() {
        transport.onEvent = nil
        transport.stop()
        viewModel.endLocalPlay()
        mode = .singleDevice
        role = nil
        session = nil
        sessionID = nil
        discoveredSessions.removeAll()
        connectionStatus = .waiting
        error = nil
        latestSnapshot = nil
        voting = nil
        clientID = UUID()
        reconnectToken = nil
        hostPeer = nil
        peersByRole.removeAll()
        pendingPeers.removeAll()
        acceptedActionIDs.removeAll()
        assignmentHistory.removeAll()
        historyRoundID = nil
        welcomedPeers.removeAll()
        outboundTasks.removeAll()
        hostIsForeground = true
        pauseRequested = false
        awaitingSnapshot = false
        recoveringPeers.removeAll()
        endingSession = false
    }

    func startHosting(serviceName: String = "ColorGame") throws {
        guard !endingSession else { throw LocalPlayError.invalidSession }
        transport.onEvent = { [weak self] event in self?.handle(event) }
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
        voting = nil
        hostIsForeground = true
        pauseRequested = false
        recoveringPeers.removeAll()
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
        guard !endingSession else { return }
        transport.onEvent = { [weak self] event in self?.handle(event) }
        mode = .threeDevices
        discoveredSessions = []
        error = nil
        transport.browse()
    }

    func join(_ discovered: DiscoveredSession) {
        guard !endingSession else { return }
        mode = .threeDevices
        error = nil
        connectionStatus = .waiting
        transport.connect(discovered)
    }

    func handle(_ event: TransportEvent) {
        guard !endingSession, mode == .threeDevices else { return }
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
                awaitingSnapshot = true
                let hello = WireMessage.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                     clientID: clientID, sessionID: sessionID,
                                                     reconnectToken: reconnectToken))
                Task { [weak self] in
                    guard let self, self.hostPeer == peer, self.mode == .threeDevices else { return }
                    do { try await self.transport.send(hello, to: peer) }
                    catch {
                        guard self.hostPeer == peer, self.mode == .threeDevices else { return }
                        self.error = error as? LocalPlayError ?? .disconnected
                    }
                }
            }
        case .disconnected(let peer):
            pendingPeers.remove(peer)
            welcomedPeers.remove(peer)
            outboundTasks.removeValue(forKey: peer)
            if role == .host, let assigned = peersByRole.first(where: { $0.value == peer })?.key {
                peersByRole.removeValue(forKey: assigned)
                if recoveringPeers[assigned]?.peer == peer { recoveringPeers.removeValue(forKey: assigned) }
                updateSeat(assigned, status: .disconnected)
            } else if hostPeer == peer {
                hostPeer = nil
                connectionStatus = .disconnected
                awaitingSnapshot = true
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
                        voting = snapshot.voting
                        awaitingSnapshot = false
                        error = nil
                    } catch {
                        self.error = error as? LocalPlayError ?? .invalidMessage
                        transport.disconnect(peer)
                    }
                case .end(let end):
                    guard end.sessionID == sessionID else { return }
                    finishSession()
                default: break
                }
            }
        case .failure(let failure):
            error = failure
        }
    }

    private func recordAssignment() {
        guard role == .host else { return }
        if viewModel.phase == .settings || viewModel.phase == .score || viewModel.phase == .gameOver { voting = nil }
        if historyRoundID != viewModel.roundID {
            historyRoundID = viewModel.roundID
            if viewModel.roundID != nil && (viewModel.phase == .playing || viewModel.phase == .result) {
                voting = .init(id: UUID(), votes: [])
            }
            assignmentHistory.removeAll()
            acceptedActionIDs.removeAll()
        }
        guard let epoch = viewModel.assignmentEpoch,
              let assignments = viewModel.round?.assignments,
              assignments.count == PlayerID.allCases.count else { return }
        if assignmentHistory[epoch] == nil { assignmentHistory[epoch] = assignments }
    }

    private func publishChange() {
        guard !endingSession, role == .host, var current = session else { return }
        current.snapshotRevision += 1
        session = current
        broadcastSnapshot()
    }

    private func broadcastSnapshot() {
        guard let session else { return }
        if role == .host && viewModel.phase == .settings {
            viewModel.timerSecondsRemaining = viewModel.reassignmentDuration
        }
        do {
            let snapshot = try snapshotMapper.makeSnapshot(from: viewModel, session: session, voting: voting)
            latestSnapshot = snapshot
            for peer in welcomedPeers { enqueue(.snapshot(snapshot), to: peer) }
        } catch {
            self.error = error as? LocalPlayError ?? .invalidMessage
        }
    }

    private func enqueue(_ message: WireMessage, to peer: PeerHandle,
                         afterSend: (() -> Void)? = nil) {
        guard !endingSession else { return }
        let previous = outboundTasks[peer]
        let queuedSessionID = sessionID
        outboundTasks[peer] = Task { [weak self] in
            await previous?.value
            guard let self, !self.endingSession, self.sessionID == queuedSessionID else { return }
            do {
                try await self.transport.send(message, to: peer)
                guard !self.endingSession, self.sessionID == queuedSessionID else { return }
                afterSend?()
            } catch {
                guard !self.endingSession, self.sessionID == queuedSessionID else { return }
                self.error = error as? LocalPlayError ?? .disconnected
                self.transport.disconnect(peer)
            }
        }
    }

    func setPaused(_ paused: Bool) {
        guard role == .host, viewModel.phase != .settings else { return }
        pauseRequested = paused
        refreshPause()
    }

    func hostDidEnterBackground() async {
        hostWillEnterBackground()
        await flushBackgroundSnapshot()
    }

    func hostWillEnterBackground() {
        guard role == .host else { return }
        hostIsForeground = false
        refreshPause()
    }

    func flushBackgroundSnapshot() async {
        guard role == .host else { return }
        for task in Array(outboundTasks.values) { await task.value }
    }

    func appDidBecomeActive() {
        guard !endingSession else { return }
        transport.resume()
        if role == .host {
            hostIsForeground = true
            refreshPause()
        }
    }

    private func refreshPause() {
        guard role == .host, viewModel.phase != .settings,
              var current = session else { return }
        let shouldPause = shouldPause(for: current.seats)
        guard current.paused != shouldPause else { return }
        current.paused = shouldPause
        session = current
        if shouldPause { viewModel.pauseSessionClocks() } else { viewModel.resumeSessionClocks() }
        publishChange()
    }

    private func shouldPause(for seats: [SessionSeat]) -> Bool {
        viewModel.phase != .settings &&
        (pauseRequested || !hostIsForeground ||
         !recoveringPeers.isEmpty ||
         seats.count != PlayerID.allCases.count ||
         seats.contains { $0.status != .connected })
    }

    private func performLocalColor(_ slot: ColorSlot) {
        guard let role, let assignment = viewModel.round?.assignments[role.playerID],
              let epoch = viewModel.assignmentEpoch else { return }
        let color = slot == .primary ? assignment.primaryColor : assignment.secondaryColor
        perform(.addColor(slot: slot, observedColorID: color.id, assignmentEpoch: epoch))
    }

    func canVote(_ action: LocalVoteAction) -> Bool {
        guard !endingSession, let role, voting != nil,
              connectionStatus == .connected, !paused,
              seatStatus.count == PlayerID.allCases.count,
              seatStatus.allSatisfy({ $0.status == .connected }),
              voting?.votes.contains(where: { $0.player == role.playerID }) == false,
              role != .host || (hostIsForeground && recoveringPeers.isEmpty),
              role == .host || (!awaitingSnapshot && hostPeer != nil) else { return false }
        return isVoteEligible(action)
    }

    private func isVoteEligible(_ action: LocalVoteAction) -> Bool {
        switch action {
        case .mix: return viewModel.canMix
        case .finish: return viewModel.canFinish
        case .apply: return viewModel.canApply
        case .redo: return viewModel.canRedo
        }
    }

    @discardableResult
    func castVote(_ action: LocalVoteAction) -> Bool {
        guard canVote(action), let voting else { return false }
        return perform(.vote(action: action, votingID: voting.id))
    }

    @discardableResult
    func perform(_ action: LocalGameAction) -> Bool {
        guard !endingSession else { return false }
        if case .returnToLobby = action {
            guard role == .host, connectionStatus == .connected, var current = session else { return false }
            pauseRequested = false
            current.paused = false
            session = current
            viewModel.returnToSettings()
            return viewModel.phase == .settings
        }
        if case .startRun = action {
            guard canStartRun else { return false }
            viewModel.startEndlessRun()
            return viewModel.run != nil && viewModel.phase == .playing
        }
        if case .startRound = action {
            guard canStartRound else { return false }
            viewModel.confirmSettings()
            return viewModel.phase == .playing && viewModel.roundID != nil
        }
        if role == .host, connectionStatus == .connected,
           let session, session.seats.count == PlayerID.allCases.count,
           session.seats.allSatisfy({ $0.status == .connected }), !session.paused {
            switch action {
            case .continueRun:
                guard viewModel.canContinueRun else { return false }
                viewModel.continueRun()
                return viewModel.phase == .playing
            case .restartRun:
                guard viewModel.phase == .gameOver else { return false }
                viewModel.restartRun()
                return viewModel.phase == .playing
            case .newRound:
                guard viewModel.phase == .score else { return false }
                viewModel.startNewRound()
                return viewModel.phase == .settings || viewModel.phase == .playing
            default: break
            }
        }
        guard let role, let sessionID, let roundID = viewModel.roundID,
              connectionStatus == .connected, !paused,
              (role == .host || !awaitingSnapshot) else { return false }
        switch action {
        case let .vote(voteAction, votingID):
            guard canVote(voteAction), voting?.id == votingID else { return false }
        case let .addColor(slot, observedColorID, epoch):
            guard viewModel.phase == .playing, viewModel.round?.mix.isLocked == false,
                  epoch == viewModel.assignmentEpoch,
                  let assignment = viewModel.round?.assignments[role.playerID],
                  (slot == .primary ? assignment.primaryColor.id : assignment.secondaryColor.id) == observedColorID else {
                return false
            }
        default: return false
        }
        let input = WireMessage.Input(sessionID: sessionID, roundID: roundID,
                                      actionID: UUID(), action: action)
        if role == .host { return acceptInput(input, from: .host) }
        guard let hostPeer else { return false }
        Task { [weak self] in
            guard let self, self.hostPeer == hostPeer,
                  self.sessionID == input.sessionID else { return }
            do { try await self.transport.send(.input(input), to: hostPeer) }
            catch {
                guard self.hostPeer == hostPeer, self.sessionID == input.sessionID else { return }
                self.error = error as? LocalPlayError ?? .disconnected
            }
        }
        return true
    }

    private func acceptInput(_ input: WireMessage.Input, from source: SessionRole) -> Bool {
        if role == .host && !paused { viewModel.refreshRunBudget() }
        guard role == .host, let session, hostIsForeground, recoveringPeers.isEmpty,
              connectionStatus == .connected,
              input.sessionID == session.sessionID,
              input.roundID == viewModel.roundID,
              session.seats.count == PlayerID.allCases.count,
              session.seats.allSatisfy({ $0.status == .connected }),
              session.seats.contains(where: { $0.role == source }),
              !session.paused, !acceptedActionIDs.contains(input.actionID) else { return false }
        switch input.action {
        case .vote:
            guard let proposed = proposedVoting(for: input, from: source) else { return false }
            acceptedActionIDs.insert(input.actionID)
            if let decision = proposed.votes.first(where: { vote in
                proposed.votes.filter { $0.action == vote.action }.count >= 2
            })?.action {
                guard isVoteEligible(decision) else { return false }
                voting = decision == .finish || decision == .apply ? nil : .init(id: UUID(), votes: [])
                switch decision {
                case .mix: viewModel.pressMixButton()
                case .finish: viewModel.selectFinish()
                case .apply: viewModel.selectApply()
                case .redo: viewModel.selectRedo()
                }
            } else {
                voting = proposed
                publishChange()
            }
            return true
        case let .addColor(slot, observedColorID, epoch):
            guard viewModel.phase == .playing, viewModel.round?.mix.isLocked == false,
                  let assignment = assignmentHistory[epoch]?[source.playerID] else { return false }
            let color = slot == .primary ? assignment.primaryColor : assignment.secondaryColor
            guard color.id == observedColorID,
                  viewModel.acceptColor(color, for: source.playerID) else { return false }
            acceptedActionIDs.insert(input.actionID)
            return true
        default: return false
        }
    }

    private func proposedVoting(for input: WireMessage.Input, from source: SessionRole) -> LocalVotingState? {
        guard case let .vote(action, votingID) = input.action,
              var proposed = voting, proposed.id == votingID,
              !proposed.votes.contains(where: { $0.player == source.playerID }),
              isVoteEligible(action) else { return nil }
        proposed.votes.append(.init(player: source.playerID, action: action))
        return proposed
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
        let recoveryAttempt = viewModel.phase == .settings ? nil : UUID()
        if let recoveryAttempt {
            recoveringPeers[assigned] = (peer, recoveryAttempt)
            refreshPause()
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
            guard let self, !self.endingSession, self.peersByRole[assigned] == peer else { return }
            self.welcomedPeers.insert(peer)
            guard let session = self.session,
                  let snapshot = try? self.snapshotMapper.makeSnapshot(from: self.viewModel, session: session, voting: self.voting) else {
                self.transport.disconnect(peer)
                return
            }
            self.enqueue(.snapshot(snapshot), to: peer) { [weak self] in
                guard let self, self.peersByRole[assigned] == peer,
                      let recoveryAttempt,
                      self.recoveringPeers[assigned]?.attempt == recoveryAttempt else { return }
                self.recoveringPeers.removeValue(forKey: assigned)
                self.refreshPause()
            }
        }
    }

    private func updateSeat(_ role: SessionRole, status: SessionStatus) {
        guard let current = session,
              let index = current.seats.firstIndex(where: { $0.role == role }),
              current.seats[index].status != status else { return }
        var seats = current.seats
        seats[index].status = status
        let shouldPause = shouldPause(for: seats)
        session = try! SessionState(sessionID: current.sessionID, seats: seats,
                                    paused: shouldPause,
                                    snapshotRevision: current.snapshotRevision + 1)
        if current.paused != shouldPause {
            if shouldPause { viewModel.pauseSessionClocks() } else { viewModel.resumeSessionClocks() }
        }
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
