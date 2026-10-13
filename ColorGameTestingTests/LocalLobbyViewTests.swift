import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class LocalLobbyViewTests: XCTestCase {
    private final class LobbyTransport: LocalPeerTransport {
        var onEvent: (@MainActor (TransportEvent) -> Void)?
        var hosted = 0
        var browsed = 0
        var resumed = 0
        var joined: DiscoveredSession?
        var hostingError: LocalPlayError?

        func host(serviceName: String) throws {
            hosted += 1
            if let hostingError { throw hostingError }
        }
        func browse() { browsed += 1 }
        func connect(_ session: DiscoveredSession) { joined = session }
        func send(_ message: WireMessage, to peer: PeerHandle) async throws {}
        func disconnect(_ peer: PeerHandle) {}
        func startHeartbeats(sessionID: UUID) {}
        func resume() { resumed += 1 }
        func stop() {}
    }

    private func makeLobby() -> (LocalPlayCoordinator, LobbyTransport) {
        let transport = LobbyTransport()
        return (LocalPlayCoordinator(viewModel: GameViewModel(), transport: transport), transport)
    }

    private func buttons(in value: Any) -> [Button<Text>] {
        if let button = value as? Button<Text> { return [button] }
        return Mirror(reflecting: value).children.flatMap { buttons(in: $0.value) }
    }

    private func texts(in value: Any) -> [String] {
        if let heading = value as? PlaytestHeading { return texts(in: heading.body) }
        if let text = value as? Text { return [String(describing: text)] }
        return Mirror(reflecting: value).children.flatMap { texts(in: $0.value) }
    }

    private func label(of button: Button<Text>) -> String {
        String(describing: Mirror(reflecting: button).children.first { $0.label == "label" }!.value)
    }

    private func press(_ title: String, in buttons: [Button<Text>], file: StaticString = #filePath, line: UInt = #line) {
        guard let button = buttons.first(where: { label(of: $0).contains(title) }),
              let action = Mirror(reflecting: button).children.first(where: { $0.label == "action" })?.value,
              let closure = Mirror(reflecting: action).children.first?.value as? @MainActor () -> Void else {
            XCTFail("Missing button \(title)", file: file, line: line)
            return
        }
        closure()
    }

    func testCreateBrowseJoinAndRetryActions() throws {
        let (coordinator, transport) = makeLobby()
        XCTAssertTrue(buttons(in: LocalLobbyView(coordinator: coordinator).body).contains { label(of: $0).contains("Create Session") })
        XCTAssertTrue(buttons(in: LocalLobbyView(coordinator: coordinator).body).contains { label(of: $0).contains("Find Sessions") })

        press("Find Sessions", in: buttons(in: LocalLobbyView(coordinator: coordinator).body))
        XCTAssertEqual(transport.browsed, 1)
        let session = DiscoveredSession(id: UUID(), name: "Kitchen Game")
        transport.onEvent?(.discovered(session))
        let joinButton = LocalLobbyView(coordinator: coordinator).sessionButton(session)
        XCTAssertTrue(label(of: joinButton).contains("Join Kitchen Game"))
        press("Join Kitchen Game", in: [joinButton])
        XCTAssertEqual(transport.joined, session)

        transport.onEvent?(.failure(.sessionNotFound))
        XCTAssertTrue(texts(in: LocalLobbyView(coordinator: coordinator).body).contains { $0.contains("not available") })
        press("Try Again", in: buttons(in: LocalLobbyView(coordinator: coordinator).body))
        XCTAssertEqual(transport.browsed, 2)

        press("Create Session", in: buttons(in: LocalLobbyView(coordinator: coordinator).body))
        XCTAssertEqual(transport.hosted, 1)
    }

    func testHostSeatsAndWaitingState() throws {
        let (coordinator, _) = makeLobby()
        try coordinator.startHosting()
        let initial = texts(in: LocalLobbyView(coordinator: coordinator).body)
        XCTAssertFalse(initial.contains { $0.contains("Your role:") })
        XCTAssertEqual(LocalLobbyView(coordinator: coordinator).status(for: .host), .connected)
        XCTAssertEqual(LocalLobbyView(coordinator: coordinator).status(for: .player2), .waiting)
        XCTAssertEqual(LocalLobbyView(coordinator: coordinator).status(for: .player3), .waiting)
        XCTAssertTrue(buttons(in: LocalLobbyView(coordinator: coordinator).body).contains { label(of: $0).contains("End Session") })

        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                   clientID: UUID(), sessionID: nil,
                                                   reconnectToken: nil)), from: peer))
        coordinator.handle(.disconnected(peer))
        let waiting = texts(in: LocalLobbyView(coordinator: coordinator).body)
        XCTAssertEqual(LocalLobbyView(coordinator: coordinator).status(for: .player2), .disconnected)
        XCTAssertTrue(waiting.contains { $0.contains("Waiting for Player 2") })
    }

    func testHostFailureResumesExistingSessionWithoutReplacingSeats() {
        let (coordinator, transport) = makeLobby()
        press("Create Session", in: buttons(in: LocalLobbyView(coordinator: coordinator).body))
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                   clientID: UUID(), sessionID: nil,
                                                   reconnectToken: nil)), from: peer))
        let sessionID = coordinator.sessionID
        let seats = coordinator.session?.seats.map(\.clientID)
        XCTAssertEqual(seats?.count, 2)
        coordinator.handle(.failure(.wifiUnavailable))
        XCTAssertTrue(texts(in: LocalLobbyView(coordinator: coordinator).body).contains { $0.contains("Wi-Fi is unavailable") })
        press("Try Again", in: buttons(in: LocalLobbyView(coordinator: coordinator).body))
        XCTAssertEqual(transport.resumed, 1)
        XCTAssertEqual(transport.hosted, 1)
        XCTAssertEqual(coordinator.sessionID, sessionID)
        XCTAssertEqual(coordinator.session?.seats.map(\.clientID), seats)
    }

    func testGuestFailureResumesExistingJoinAndClearsErrorOnlyAfterSnapshot() throws {
        let (coordinator, transport) = makeLobby()
        let session = DiscoveredSession(id: UUID(), name: "Kitchen Game")
        coordinator.startBrowsing()
        coordinator.handle(.discovered(session))
        coordinator.join(session)
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.welcome(.init(sessionID: UUID(), role: .player2,
                                                    reconnectToken: UUID())), from: peer))
        let sessionID = try XCTUnwrap(coordinator.sessionID)
        coordinator.handle(.disconnected(peer))
        coordinator.handle(.failure(.disconnected))
        press("Try Again", in: buttons(in: LocalLobbyView(coordinator: coordinator).body))
        XCTAssertEqual(transport.resumed, 1)
        XCTAssertEqual(transport.browsed, 1)
        XCTAssertEqual(transport.joined, session)
        XCTAssertEqual(coordinator.role, .player2)
        XCTAssertEqual(coordinator.sessionID, sessionID)

        let recoveredPeer = PeerHandle(id: UUID())
        coordinator.handle(.connected(recoveredPeer))
        coordinator.handle(.received(.welcome(.init(sessionID: sessionID, role: .player2,
                                                    reconnectToken: UUID())), from: recoveredPeer))
        XCTAssertEqual(coordinator.error, .disconnected)
        XCTAssertTrue(buttons(in: LocalLobbyView(coordinator: coordinator).body).contains { label(of: $0).contains("Try Again") })

        let snapshotSession = try SessionState(sessionID: sessionID, seats: [
            .init(role: .host, clientID: UUID(), reconnectToken: nil, status: .connected),
            .init(role: .player2, clientID: UUID(), reconnectToken: UUID(), status: .connected)
        ], paused: false, snapshotRevision: 1)
        let wrongSession = try SessionState(sessionID: UUID(), seats: snapshotSession.seats,
                                            paused: false, snapshotRevision: 2)
        coordinator.handle(.received(.snapshot(try LocalGameSnapshotMapper().makeSnapshot(
            from: GameViewModel(), session: wrongSession, voting: nil)), from: recoveredPeer))
        XCTAssertEqual(coordinator.error, .disconnected)
        let snapshot = try LocalGameSnapshotMapper().makeSnapshot(from: GameViewModel(), session: snapshotSession, voting: nil)
        coordinator.handle(.received(.snapshot(snapshot), from: recoveredPeer))
        XCTAssertNil(coordinator.error)
        XCTAssertFalse(buttons(in: LocalLobbyView(coordinator: coordinator).body).contains { label(of: $0).contains("Try Again") })
        XCTAssertEqual(coordinator.role, .player2)
        XCTAssertEqual(coordinator.sessionID, sessionID)
    }

    func testGuestOnlySeesGuestControlsAndCanLeave() async throws {
        let (coordinator, transport) = makeLobby()
        let peer = PeerHandle(id: UUID())
        coordinator.startBrowsing()
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.welcome(.init(sessionID: UUID(), role: .player2,
                                                    reconnectToken: UUID())), from: peer))

        let guest = texts(in: LocalLobbyView(coordinator: coordinator).body)
        let guestButtons = buttons(in: LocalLobbyView(coordinator: coordinator).body).map(label)
        XCTAssertFalse(guest.contains { $0.contains("Your role:") })
        XCTAssertEqual(LocalLobbyView(coordinator: coordinator).status(for: .host), .connected)
        XCTAssertEqual(LocalLobbyView(coordinator: coordinator).status(for: .player2), .connected)
        XCTAssertEqual(LocalLobbyView(coordinator: coordinator).status(for: .player3), .waiting)
        XCTAssertTrue(guestButtons.contains { $0.contains("Leave Session") })
        XCTAssertFalse(guestButtons.contains { $0.contains("Create Session") })
        XCTAssertFalse(guestButtons.contains { $0.contains("End Session") })
        XCTAssertFalse(guestButtons.contains { $0.contains("Start Round") })
        XCTAssertEqual(transport.hosted, 0)

        coordinator.handle(.disconnected(peer))
        let disconnected = texts(in: LocalLobbyView(coordinator: coordinator).body)
        XCTAssertEqual(LocalLobbyView(coordinator: coordinator).status(for: .host), .disconnected)
        XCTAssertTrue(disconnected.contains { $0.contains("Waiting for host") })
        press("Leave Session", in: buttons(in: LocalLobbyView(coordinator: coordinator).body))
        for _ in 0..<50 where coordinator.role != nil { await Task.yield() }
        XCTAssertNil(coordinator.role)
    }
}
