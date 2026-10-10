import Foundation

enum TransportEvent {
    case discovered(DiscoveredSession)
    case connected(PeerHandle)
    case disconnected(PeerHandle)
    case received(WireMessage, from: PeerHandle)
    case failure(LocalPlayError)
}

@MainActor
protocol LocalPeerTransport: AnyObject {
    var onEvent: (@MainActor (TransportEvent) -> Void)? { get set }

    func host(serviceName: String) throws
    func browse()
    func connect(_ session: DiscoveredSession)
    func send(_ message: WireMessage, to peer: PeerHandle) async throws
    func disconnect(_ peer: PeerHandle)
    func startHeartbeats(sessionID: UUID)
    func resume()
    func stop()
}

@MainActor
protocol LocalPlayScheduledTask: AnyObject {
    func cancel()
}

@MainActor
protocol LocalPlayClock: AnyObject {
    var now: TimeInterval { get }
    func schedule(after seconds: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any LocalPlayScheduledTask
}

@MainActor
final class SystemLocalPlayClock: LocalPlayClock {
    private final class Scheduled: LocalPlayScheduledTask {
        var task: Task<Void, Never>?
        func cancel() { task?.cancel() }
    }

    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func schedule(after seconds: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any LocalPlayScheduledTask {
        let scheduled = Scheduled()
        scheduled.task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            action()
        }
        return scheduled
    }
}
