import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor final class LocalPeerTransportTests: XCTestCase {
    func testFakePeersConnectSendDisconnectAndAdvanceClock() async throws {
        let network = FakePeerNetwork()
        let host = network.makePeer()
        let client = network.makePeer()
        let clock = FakeLocalPlayClock()
        var hostEvents: [TransportEvent] = []
        var clientEvents: [TransportEvent] = []
        host.onEvent = { hostEvents.append($0) }
        client.onEvent = { clientEvents.append($0) }

        try host.host(serviceName: "Color game")
        client.browse()
        guard case .discovered(let session) = clientEvents.first else {
            return XCTFail("Client did not discover host")
        }
        client.connect(session)
        guard case .connected(let hostHandle) = clientEvents.last else {
            return XCTFail("Client did not connect")
        }
        XCTAssertEqual(hostHandle, host.handle)
        guard case .connected(let clientHandle) = hostEvents.last else {
            return XCTFail("Host did not connect")
        }
        XCTAssertEqual(clientHandle, client.handle)

        let sessionID = UUID()
        try await client.send(.heartbeat(.init(sessionID: sessionID, ping: 7)), to: hostHandle)
        guard case .received(.heartbeat(let heartbeat), from: let sender) = hostEvents.last else {
            return XCTFail("Host did not receive typed message")
        }
        XCTAssertEqual(sender, client.handle)
        XCTAssertEqual(heartbeat.sessionID, sessionID)
        XCTAssertEqual(heartbeat.ping, 7)

        var ticks = 0
        clock.schedule(after: 3) { ticks += 1 }
        clock.advance(by: 2)
        XCTAssertEqual(ticks, 0)
        clock.advance(by: 1)
        XCTAssertEqual(clock.now, 3)
        XCTAssertEqual(ticks, 1)

        client.stop()
        guard case .disconnected(let disconnectedClient) = hostEvents.last else {
            return XCTFail("Host did not receive disconnect")
        }
        XCTAssertEqual(disconnectedClient, client.handle)
        guard case .disconnected(let disconnectedHost) = clientEvents.last else {
            return XCTFail("Client did not receive disconnect")
        }
        XCTAssertEqual(disconnectedHost, host.handle)
        do {
            try await client.send(.heartbeat(.init(sessionID: sessionID, ping: 8)), to: hostHandle)
            XCTFail("Sending after disconnect should fail")
        } catch {
            XCTAssertEqual(error as? LocalPlayError, .disconnected)
        }
    }

    func testClockCancellationAndDeadlineOrder() {
        let clock = FakeLocalPlayClock()
        var fired: [String] = []
        clock.schedule(after: 9) { fired.append("late") }
        let cancelled = clock.schedule(after: 3) { fired.append("cancelled") }
        clock.schedule(after: 3) { fired.append("early") }
        cancelled.cancel()
        clock.advance(by: 9)
        XCTAssertEqual(fired, ["early", "late"])
    }

    func testMissingSessionReportsFailure() {
        let client = FakePeerNetwork().makePeer()
        var error: LocalPlayError?
        client.onEvent = { event in
            if case .failure(let failure) = event { error = failure }
        }
        client.connect(.init(id: UUID(), name: "Missing"))
        XCTAssertEqual(error, .sessionNotFound)
    }
}
