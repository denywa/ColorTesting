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

    private let viewModel: GameViewModel
    private let transport: any LocalPeerTransport
    private let clientID = UUID()
    private var reconnectToken: UUID?
    private var hostPeer: PeerHandle?
    private var peersByRole: [SessionRole: PeerHandle] = [:]
    private var pendingPeers: Set<PeerHandle> = []

    init(viewModel: GameViewModel, transport: any LocalPeerTransport) {
        self.viewModel = viewModel
        self.transport = transport
        transport.onEvent = { [weak self] event in self?.handle(event) }
    }

    var canStartRound: Bool {
        role == .host && session?.seats.count == 3 &&
        session?.seats.allSatisfy { $0.status == .connected } == true
    }

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
                    transport.startHeartbeats(sessionID: welcome.sessionID)
                case .reject(let rejection):
                    error = rejection.reason
                    transport.disconnect(peer)
                    transport.browse()
                default: break
                }
            }
        case .failure(let failure):
            error = failure
        }
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
        Task { [weak self] in
            guard let self else { return }
            do { try await self.transport.send(welcome, to: peer) }
            catch { self.transport.disconnect(peer) }
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
