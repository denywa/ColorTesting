import XCTest
@testable import ColorGameTesting

@MainActor
final class LocalPlayCoordinatorTests: XCTestCase {
    private final class RetryingHostTransport: LocalPeerTransport {
        var onEvent: (@MainActor (TransportEvent) -> Void)?
        var sent: [WireMessage] = []
        var heartbeatSessionID: UUID?

        func host(serviceName: String) throws { throw LocalPlayError.wifiUnavailable }
        func browse() {}
        func connect(_ session: DiscoveredSession) {}
        func send(_ message: WireMessage, to peer: PeerHandle) async throws { sent.append(message) }
        func disconnect(_ peer: PeerHandle) {}
        func startHeartbeats(sessionID: UUID) { heartbeatSessionID = sessionID }
        func resume() {}
        func stop() {}
    }

    private func makeCoordinator(_ network: FakePeerNetwork) -> LocalPlayCoordinator {
        LocalPlayCoordinator(viewModel: GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!),
                             transport: network.makePeer())
    }

    private func waitUntil(_ predicate: @escaping () -> Bool) async {
        for _ in 0..<100 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Expected lobby state did not arrive")
    }

    func testHostAssignsThreeUniqueSeatsAndStartGate() async throws {
        let network = FakePeerNetwork()
        let host = makeCoordinator(network)
        let second = makeCoordinator(network)
        let third = makeCoordinator(network)

        try host.startHosting()
        XCTAssertEqual(host.role, .host)
        XCTAssertFalse(host.canStartRound)

        second.startBrowsing()
        let session = try XCTUnwrap(second.discoveredSessions.first)
        second.join(session)
        await waitUntil { second.role == .player2 }
        XCTAssertFalse(host.canStartRound)

        third.startBrowsing()
        third.join(try XCTUnwrap(third.discoveredSessions.first))
        await waitUntil { third.role == .player3 }
        XCTAssertEqual(host.session?.seats.map(\.role), [.host, .player2, .player3])
        XCTAssertTrue(host.canStartRound)
    }

    func testHostRetainsRoleWhenTransportThrowsThenRetries() async throws {
        let transport = RetryingHostTransport()
        let host = LocalPlayCoordinator(viewModel: GameViewModel(), transport: transport)
        XCTAssertThrowsError(try host.startHosting()) { error in
            XCTAssertEqual(error as? LocalPlayError, .wifiUnavailable)
        }
        XCTAssertEqual(host.role, .host)
        XCTAssertEqual(transport.heartbeatSessionID, host.sessionID)
        let peer = PeerHandle(id: UUID())
        transport.onEvent?(.connected(peer))
        transport.onEvent?(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                 clientID: UUID(), sessionID: nil,
                                                 reconnectToken: nil)), from: peer))
        await waitUntil { !transport.sent.isEmpty }
        guard case .welcome(let welcome) = transport.sent.first else {
            return XCTFail("Expected Welcome after transport retry")
        }
        XCTAssertEqual(welcome.role, .player2)
        XCTAssertEqual(welcome.sessionID, host.sessionID)
        XCTAssertEqual(host.session?.seats.count, 2)
    }

    func testFourthPeerAndWrongVersionAreRejectedWithoutChangingSeats() async throws {
        let network = FakePeerNetwork()
        let host = makeCoordinator(network)
        let second = makeCoordinator(network)
        let third = makeCoordinator(network)
        let fourth = makeCoordinator(network)
        try host.startHosting()
        for client in [second, third] {
            client.startBrowsing()
            client.join(try XCTUnwrap(client.discoveredSessions.first))
            await waitUntil { client.role != nil }
        }
        let occupied = host.session?.seats.map(\.clientID)
        fourth.startBrowsing()
        fourth.join(try XCTUnwrap(fourth.discoveredSessions.first))
        await waitUntil { fourth.error == .sessionFull }
        XCTAssertNil(fourth.role)
        XCTAssertEqual(fourth.discoveredSessions.count, 1)
        XCTAssertEqual(host.session?.seats.map(\.clientID), occupied)

        let wrong = network.makePeer()
        var wrongVersionRejection: LocalPlayError?
        wrong.onEvent = { event in
            if case .received(.reject(let rejection), from: _) = event {
                wrongVersionRejection = rejection.reason
            }
        }
        wrong.connect(try XCTUnwrap(second.discoveredSessions.first))
        let hostHandle = try XCTUnwrap(wrong.connected.first)
        try await wrong.send(.hello(.init(protocolVersion: LocalPlayProtocol.version + 1,
                                          clientID: UUID(), sessionID: nil, reconnectToken: nil)),
                             to: hostHandle)
        await waitUntil { wrongVersionRejection == .versionMismatch }
        XCTAssertEqual(host.session?.seats.map(\.clientID), occupied)
    }

    func testReconnectTokenReplacesStalePeerWithoutReleasingSeat() async throws {
        let network = FakePeerNetwork()
        let host = makeCoordinator(network)
        let original = makeCoordinator(network)
        try host.startHosting()
        original.startBrowsing()
        let discovery = try XCTUnwrap(original.discoveredSessions.first)
        original.join(discovery)
        await waitUntil { original.role == .player2 }
        let seat = try XCTUnwrap(host.session?.seats.first { $0.role == .player2 })
        let token = try XCTUnwrap(seat.reconnectToken)

        let replacement = network.makePeer()
        var replacementRole: SessionRole?
        replacement.onEvent = { event in
            if case .received(.welcome(let welcome), from: _) = event {
                replacementRole = welcome.role
            }
        }
        replacement.connect(discovery)
        try await replacement.send(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                clientID: seat.clientID,
                                                sessionID: host.sessionID,
                                                reconnectToken: token)),
                                   to: try XCTUnwrap(replacement.connected.first))
        await waitUntil { replacementRole == .player2 }
        XCTAssertEqual(original.connectionStatus, .disconnected)
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.status, .connected)
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.clientID, seat.clientID)
        XCTAssertEqual(host.session?.seats.count, 2)
    }

    func testDisconnectedSeatRetainsIdentityAndCanReconnect() async throws {
        let network = FakePeerNetwork()
        let host = makeCoordinator(network)
        let secondTransport = network.makePeer()
        let second = LocalPlayCoordinator(viewModel: GameViewModel(), transport: secondTransport)
        try host.startHosting()
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        await waitUntil { second.role == .player2 }
        let seat = try XCTUnwrap(host.session?.seats.first { $0.role == .player2 })
        XCTAssertNotNil(seat.reconnectToken)

        secondTransport.stop()
        XCTAssertFalse(host.canStartRound)
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.status, .disconnected)
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        await waitUntil { host.session?.seats.first { $0.role == .player2 }?.status == .connected }
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.clientID, seat.clientID)
        XCTAssertEqual(second.role, .player2)
    }
}
