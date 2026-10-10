import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor final class LocalNetworkTransportTests: XCTestCase {
    func testTwoFakePeersExchangeOrderedMessages() async throws {
        let network = FakePeerNetwork()
        let host = network.makePeer()
        let client = network.makePeer()
        var hostPings: [UInt64] = []
        var clientPings: [UInt64] = []
        host.onEvent = { event in
            if case .received(.heartbeat(let heartbeat), from: _) = event { hostPings.append(heartbeat.ping) }
        }
        client.onEvent = { event in
            switch event {
            case .discovered(let session): client.connect(session)
            case .received(.heartbeat(let heartbeat), from: _): clientPings.append(heartbeat.ping)
            default: break
            }
        }
        try host.host(serviceName: "Fake color game")
        client.browse()
        let sessionID = UUID()
        for ping in [UInt64(1), 2, 3] {
            try await client.send(.heartbeat(.init(sessionID: sessionID, ping: ping)), to: host.handle)
            try await host.send(.heartbeat(.init(sessionID: sessionID, ping: ping + 10)), to: client.handle)
        }
        XCTAssertEqual(hostPings, [1, 2, 3])
        XCTAssertEqual(clientPings, [11, 12, 13])
    }

    func testHostIsDiscoveredAndAcceptsTwoClients() async throws {
        let host = LocalNetworkTransport()
        let clients = [LocalNetworkTransport(), LocalNetworkTransport()]
        let serviceName = "ColorGame-\(UUID().uuidString.prefix(8))"
        defer { host.stop(); clients.forEach { $0.stop() } }

        let discovered = clients.map { _ in expectation(description: "Bonjour session discovered") }
        let clientConnected = clients.map { _ in expectation(description: "Client connected") }
        let hostConnected = expectation(description: "Host accepted both clients")
        hostConnected.expectedFulfillmentCount = 2
        let hostReceived = expectation(description: "Host received both ordered streams")
        hostReceived.expectedFulfillmentCount = 6
        let hostDisconnected = expectation(description: "Host detects a closed peer")
        let clientReceived = clients.map { _ in expectation(description: "Client received ordered replies") }
        clientReceived.forEach { $0.expectedFulfillmentCount = 2 }
        var hostHandles: Set<PeerHandle> = []
        var clientHandles: [PeerHandle?] = [nil, nil]
        var hostMessages: [PeerHandle: [UInt64]] = [:]
        var clientMessages: [[UInt64]] = [[], []]
        host.onEvent = { event in
            switch event {
            case .connected(let handle):
                hostHandles.insert(handle)
                hostConnected.fulfill()
            case .received(.heartbeat(let heartbeat), from: let peer):
                hostMessages[peer, default: []].append(heartbeat.ping)
                hostReceived.fulfill()
            case .disconnected:
                hostDisconnected.fulfill()
            default:
                break
            }
        }
        try host.host(serviceName: serviceName)
        for index in clients.indices {
            clients[index].onEvent = { event in
                switch event {
                case .discovered(let session) where session.name == serviceName:
                    discovered[index].fulfill()
                    clients[index].connect(session)
                case .connected(let handle):
                    clientHandles[index] = handle
                    clientConnected[index].fulfill()
                case .received(.heartbeat(let heartbeat), from: _):
                    clientMessages[index].append(heartbeat.ping)
                    clientReceived[index].fulfill()
                default:
                    break
                }
            }
            clients[index].browse()
        }
        await fulfillment(of: discovered + clientConnected + [hostConnected], timeout: 15)
        XCTAssertEqual(hostHandles.count, 2)
        let firstHost = try XCTUnwrap(clientHandles[0])
        let secondHost = try XCTUnwrap(clientHandles[1])
        let sessionID = UUID()
        for ping in [UInt64(1), 2, 3] {
            try await clients[0].send(.heartbeat(.init(sessionID: sessionID, ping: ping)), to: firstHost)
            try await clients[1].send(.heartbeat(.init(sessionID: sessionID, ping: ping + 10)), to: secondHost)
        }
        await fulfillment(of: [hostReceived], timeout: 10)
        XCTAssertEqual(Set(hostMessages.values.map { $0 }), Set([[1, 2, 3], [11, 12, 13]]))

        for (index, peer) in hostMessages.keys.enumerated() {
            for ping in [UInt64(20), 21] {
                try await host.send(.heartbeat(.init(sessionID: sessionID, ping: ping + UInt64(index) * 10)), to: peer)
            }
        }
        await fulfillment(of: clientReceived, timeout: 10)
        XCTAssertEqual(Set(clientMessages), Set([[20, 21], [30, 31]]))

        let closedPeer = try XCTUnwrap(hostMessages.first { $0.value == [1, 2, 3] }?.key)
        clients[0].stop()
        await fulfillment(of: [hostDisconnected], timeout: 10)
        do {
            try await host.send(.heartbeat(.init(sessionID: sessionID, ping: 99)), to: closedPeer)
            XCTFail("Sending to a disconnected peer must fail")
        } catch {
            XCTAssertEqual(error as? LocalPlayError, .disconnected)
        }
    }

    func testUnknownSessionReportsRetryableFailure() {
        let client = LocalNetworkTransport()
        var failures: [LocalPlayError] = []
        client.onEvent = { event in
            if case .failure(let error) = event { failures.append(error) }
        }
        client.connect(.init(id: UUID(), name: "Missing"))
        XCTAssertEqual(failures, [.sessionNotFound])
        client.browse()
        client.stop()
    }

    func testHeartbeatTimesOutSilentPeerAtNineSeconds() async throws {
        let clock = FakeLocalPlayClock()
        let host = LocalNetworkTransport(clock: clock)
        let client = LocalNetworkTransport(clock: clock)
        let name = "ColorGame-\(UUID().uuidString.prefix(8))"
        defer { host.stop(); client.stop() }
        let connected = expectation(description: "host accepted client")
        let disconnected = expectation(description: "silent client disconnected")
        var didDisconnect = false
        host.onEvent = { event in
            if case .connected = event { connected.fulfill() }
            if case .disconnected = event { didDisconnect = true; disconnected.fulfill() }
        }
        client.onEvent = { event in
            if case .discovered(let session) = event, session.name == name { client.connect(session) }
        }
        try host.host(serviceName: name)
        client.browse()
        await fulfillment(of: [connected], timeout: 15)
        host.startHeartbeats(sessionID: UUID())
        clock.advance(by: 8.9)
        XCTAssertFalse(didDisconnect)
        clock.advance(by: 0.1)
        await fulfillment(of: [disconnected], timeout: 2)
    }

    func testMatchingHeartbeatsKeepBothPeersConnected() async throws {
        let clock = FakeLocalPlayClock()
        let host = LocalNetworkTransport(clock: clock)
        let client = LocalNetworkTransport(clock: clock)
        let name = "ColorGame-\(UUID().uuidString.prefix(8))"
        defer { host.stop(); client.stop() }
        let connected = expectation(description: "both peers connected")
        connected.expectedFulfillmentCount = 2
        let heartbeats = expectation(description: "both peers receive three heartbeats")
        heartbeats.expectedFulfillmentCount = 6
        var disconnects = 0
        host.onEvent = { event in
            if case .connected = event { connected.fulfill() }
            if case .received(.heartbeat, from: _) = event { heartbeats.fulfill() }
            if case .disconnected = event { disconnects += 1 }
        }
        client.onEvent = { event in
            if case .discovered(let session) = event, session.name == name { client.connect(session) }
            if case .connected = event { connected.fulfill() }
            if case .received(.heartbeat, from: _) = event { heartbeats.fulfill() }
            if case .disconnected = event { disconnects += 1 }
        }
        try host.host(serviceName: name)
        client.browse()
        await fulfillment(of: [connected], timeout: 15)
        let sessionID = UUID()
        host.startHeartbeats(sessionID: sessionID)
        client.startHeartbeats(sessionID: sessionID)
        for _ in 0..<3 {
            clock.advance(by: 3)
            try await Task.sleep(for: .milliseconds(150))
        }
        await fulfillment(of: [heartbeats], timeout: 5)
        XCTAssertEqual(disconnects, 0)
    }

    func testResumeReconnectsClientAfterHostRestartsService() async throws {
        let clock = FakeLocalPlayClock()
        let host = LocalNetworkTransport(clock: clock)
        let client = LocalNetworkTransport(clock: clock)
        let name = "ColorGame-\(UUID().uuidString.prefix(8))"
        defer { host.stop(); client.stop() }
        let first = expectation(description: "first client connection")
        let recovered = expectation(description: "client reconnects")
        var connections = 0
        client.onEvent = { event in
            switch event {
            case .discovered(let session) where session.name == name:
                if connections == 0 { client.connect(session) }
            case .connected:
                connections += 1
                if connections == 1 { first.fulfill() }
                if connections == 2 { recovered.fulfill() }
            default: break
            }
        }
        try host.host(serviceName: name)
        client.browse()
        await fulfillment(of: [first], timeout: 15)
        host.stop()
        try host.host(serviceName: name)
        client.resume()
        clock.advance(by: 3)
        await fulfillment(of: [recovered], timeout: 15)
    }

    func testHostResumeReadvertisesForNewBrowser() async throws {
        let host = LocalNetworkTransport()
        let browser = LocalNetworkTransport()
        let name = "ColorGame-\(UUID().uuidString.prefix(8))"
        defer { host.stop(); browser.stop() }
        let discovered = expectation(description: "resumed host service discovered")
        browser.onEvent = { event in
            if case .discovered(let session) = event, session.name == name { discovered.fulfill() }
        }
        try host.host(serviceName: name)
        host.resume()
        browser.browse()
        await fulfillment(of: [discovered], timeout: 15)
    }

    func testClientRetriesAfterConnectionDropsWithoutForegroundSignal() async throws {
        let clock = FakeLocalPlayClock()
        let host = LocalNetworkTransport(clock: clock)
        let client = LocalNetworkTransport(clock: clock)
        let name = "ColorGame-\(UUID().uuidString.prefix(8))"
        defer { host.stop(); client.stop() }
        let first = expectation(description: "first connection")
        let dropped = expectation(description: "host outage detected")
        let recovered = expectation(description: "automatic retry connected")
        var count = 0
        client.onEvent = { event in
            switch event {
            case .discovered(let session) where session.name == name:
                if count == 0 { client.connect(session) }
            case .connected:
                count += 1
                if count == 1 { first.fulfill() }
                if count == 2 { recovered.fulfill() }
            case .disconnected: dropped.fulfill()
            default: break
            }
        }
        try host.host(serviceName: name)
        client.browse()
        await fulfillment(of: [first], timeout: 15)
        host.stop()
        await fulfillment(of: [dropped], timeout: 10)
        try host.host(serviceName: name)
        clock.advance(by: 3)
        await fulfillment(of: [recovered], timeout: 15)
    }
}
