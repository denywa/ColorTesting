import Foundation
@testable import ColorGameTesting

@MainActor
final class FakePeerNetwork {
    private var hosts: [DiscoveredSession: FakePeerTransport] = [:]
    private var peers: [PeerHandle: FakePeerTransport] = [:]

    func makePeer() -> FakePeerTransport {
        let peer = FakePeerTransport(network: self)
        peers[peer.handle] = peer
        return peer
    }

    func host(_ peer: FakePeerTransport, name: String) {
        let session = DiscoveredSession(id: UUID(), name: name)
        hosts[session] = peer
        peer.hostedSession = session
    }

    func browse(_ peer: FakePeerTransport) {
        for session in hosts.keys { peer.onEvent?(.discovered(session)) }
    }

    func connect(_ peer: FakePeerTransport, to session: DiscoveredSession) {
        guard let host = hosts[session] else {
            peer.onEvent?(.failure(.sessionNotFound))
            return
        }
        peer.connected.insert(host.handle)
        host.connected.insert(peer.handle)
        peer.onEvent?(.connected(host.handle))
        host.onEvent?(.connected(peer.handle))
    }

    func send(_ message: WireMessage, from sender: FakePeerTransport, to handle: PeerHandle) throws {
        guard sender.connected.contains(handle), let recipient = peers[handle] else {
            throw LocalPlayError.disconnected
        }
        recipient.onEvent?(.received(message, from: sender.handle))
    }

    func disconnect(_ peer: FakePeerTransport) {
        for handle in peer.connected {
            peers[handle]?.connected.remove(peer.handle)
            peers[handle]?.onEvent?(.disconnected(peer.handle))
            peer.onEvent?(.disconnected(handle))
        }
        peer.connected.removeAll()
        if let session = peer.hostedSession {
            hosts.removeValue(forKey: session)
            peer.hostedSession = nil
        }
    }

    func disconnect(_ peer: FakePeerTransport, from handle: PeerHandle) {
        guard peer.connected.remove(handle) != nil else { return }
        peers[handle]?.connected.remove(peer.handle)
        peer.onEvent?(.disconnected(handle))
        peers[handle]?.onEvent?(.disconnected(peer.handle))
    }
}

@MainActor
final class FakePeerTransport: LocalPeerTransport {
    var onEvent: (@MainActor (TransportEvent) -> Void)?
    private(set) var resumeCount = 0
    let handle = PeerHandle(id: UUID())
    fileprivate var hostedSession: DiscoveredSession?
    var connected: Set<PeerHandle> = []
    private let network: FakePeerNetwork

    init(network: FakePeerNetwork) { self.network = network }

    func host(serviceName: String) throws { network.host(self, name: serviceName) }
    func browse() { network.browse(self) }
    func connect(_ session: DiscoveredSession) { network.connect(self, to: session) }
    func send(_ message: WireMessage, to peer: PeerHandle) async throws {
        try network.send(message, from: self, to: peer)
    }
    func disconnect(_ peer: PeerHandle) { network.disconnect(self, from: peer) }
    func startHeartbeats(sessionID: UUID) {}
    func resume() { resumeCount += 1 }
    func stop() { network.disconnect(self) }
}

@MainActor
final class FakeLocalPlayClock: LocalPlayClock {
    private final class Scheduled: LocalPlayScheduledTask {
        let deadline: TimeInterval
        let action: @MainActor () -> Void
        var cancelled = false

        init(deadline: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.deadline = deadline
            self.action = action
        }

        func cancel() { cancelled = true }
    }

    private var scheduled: [Scheduled] = []
    private(set) var now: TimeInterval = 0

    func schedule(after seconds: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any LocalPlayScheduledTask {
        let task = Scheduled(deadline: now + seconds, action: action)
        scheduled.append(task)
        return task
    }

    func advance(by seconds: TimeInterval) {
        precondition(seconds >= 0)
        let target = now + seconds
        while let index = scheduled.indices.filter({ scheduled[$0].deadline <= target }).min(by: { scheduled[$0].deadline < scheduled[$1].deadline }) {
            let task = scheduled.remove(at: index)
            now = task.deadline
            if !task.cancelled { task.action() }
        }
        now = target
    }
}
