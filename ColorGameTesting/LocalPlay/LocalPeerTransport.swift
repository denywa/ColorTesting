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
