import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor final class LocalNetworkTransportTests: XCTestCase {
    func testHostIsDiscoveredAndAcceptsTwoClients() async throws {
        let host = LocalNetworkTransport()
        let clients = [LocalNetworkTransport(), LocalNetworkTransport()]
        let serviceName = "ColorGame-\(UUID().uuidString.prefix(8))"
        defer { host.stop(); clients.forEach { $0.stop() } }

        let discovered = clients.map { _ in expectation(description: "Bonjour session discovered") }
        let clientConnected = clients.map { _ in expectation(description: "Client connected") }
        let hostConnected = expectation(description: "Host accepted both clients")
        hostConnected.expectedFulfillmentCount = 2
        var hostHandles: Set<PeerHandle> = []
        var clientHandles: [PeerHandle?] = [nil, nil]
        host.onEvent = { event in
            if case .connected(let handle) = event {
                hostHandles.insert(handle)
                hostConnected.fulfill()
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
                default:
                    break
                }
            }
            clients[index].browse()
        }
        await fulfillment(of: discovered + clientConnected + [hostConnected], timeout: 15)
        XCTAssertEqual(hostHandles.count, 2)
        let firstHost = try XCTUnwrap(clientHandles[0])
        try await clients[0].send(.heartbeat(.init(sessionID: UUID(), ping: 1)), to: firstHost)
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
}
