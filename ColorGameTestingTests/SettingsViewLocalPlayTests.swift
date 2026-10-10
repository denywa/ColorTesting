import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class SettingsViewLocalPlayTests: XCTestCase {
    private final class TestTransport: LocalPeerTransport {
        var onEvent: (@MainActor (TransportEvent) -> Void)?
        func host(serviceName: String) throws {}
        func browse() {}
        func connect(_ session: DiscoveredSession) {}
        func send(_ message: WireMessage, to peer: PeerHandle) async throws {}
        func disconnect(_ peer: PeerHandle) {}
        func startHeartbeats(sessionID: UUID) {}
        func resume() {}
        func stop() {}
    }

    private func buttons(in value: Any) -> [Button<Text>] {
        if let button = value as? Button<Text> { return [button] }
        return Mirror(reflecting: value).children.flatMap { buttons(in: $0.value) }
    }

    private func texts(in value: Any) -> [String] {
        if let text = value as? Text { return [String(describing: text)] }
        return Mirror(reflecting: value).children.flatMap { texts(in: $0.value) }
    }

    private func containsControl(_ value: Any) -> Bool {
        let type = String(describing: Swift.type(of: value))
        if type.hasPrefix("Picker<") || type.hasPrefix("Toggle<") || type.hasPrefix("ColorModelToggle") ||
            type.hasPrefix("Button<") { return true }
        return Mirror(reflecting: value).children.contains { containsControl($0.value) }
    }

    private func startButton(in view: SettingsView) throws -> Button<Text> {
        try XCTUnwrap(buttons(in: view.body).first {
            String(describing: Mirror(reflecting: $0).children.first { $0.label == "label" }!.value)
                .contains("Start Round")
        })
    }

    private func press(_ button: Button<Text>) throws {
        let action = try XCTUnwrap(Mirror(reflecting: button).children.first { $0.label == "action" }?.value)
        let closure = try XCTUnwrap(Mirror(reflecting: action).children.first?.value as? @MainActor () -> Void)
        closure()
    }

    private func joinPeer(_ coordinator: LocalPlayCoordinator) {
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                   clientID: UUID(), sessionID: nil,
                                                   reconnectToken: nil)), from: peer))
    }

    func testHostStartRequiresModelAndThreeConnectedSeats() throws {
        let model = GameViewModel()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        try coordinator.startHosting()
        var view = SettingsView(viewModel: model, coordinator: coordinator)

        XCTAssertFalse(view.canStartRound)
        model.selectModel(.cmyk)
        view = SettingsView(viewModel: model, coordinator: coordinator)
        XCTAssertFalse(view.canStartRound)
        try press(startButton(in: view))
        XCTAssertEqual(model.phase, .settings)

        joinPeer(coordinator)
        XCTAssertFalse(SettingsView(viewModel: model, coordinator: coordinator).canStartRound)
        joinPeer(coordinator)
        model.selectedModel = nil
        XCTAssertFalse(SettingsView(viewModel: model, coordinator: coordinator).canStartRound)
        model.selectModel(.cmyk)
        view = SettingsView(viewModel: model, coordinator: coordinator)
        XCTAssertTrue(view.canStartRound)
        try press(startButton(in: view))
        XCTAssertEqual(model.phase, .playing)
        XCTAssertNotNil(coordinator.latestSnapshot?.roundID)
        model.pauseTimer()
        model.removeKeyMonitor()
    }

    func testGuestSeesReadOnlyLobbyStatus() {
        let model = GameViewModel()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        coordinator.startBrowsing()
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.welcome(.init(sessionID: UUID(), role: .player2,
                                                    reconnectToken: UUID())), from: peer))

        let view = SettingsView(viewModel: model, coordinator: coordinator)
        XCTAssertTrue(texts(in: view.body).contains { $0.contains("Waiting for the host") })
        XCTAssertFalse(containsControl(view.body))
    }

    func testSoloSettingsStillStartWithoutCoordinator() throws {
        let model = GameViewModel()
        var view = SettingsView(viewModel: model)
        XCTAssertFalse(view.canStartRound)
        model.selectModel(.ryb)
        view = SettingsView(viewModel: model)
        XCTAssertTrue(view.canStartRound)
        try press(startButton(in: view))
        XCTAssertEqual(model.phase, .playing)
        model.pauseTimer()
        model.removeKeyMonitor()
    }
}
