import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class ScoreViewLocalPlayTests: XCTestCase {
    private final class TestTransport: LocalPeerTransport {
        var onEvent: (@MainActor @Sendable (TransportEvent) -> Void)?
        func host(serviceName: String) throws {}
        func browse() {}
        func connect(_ session: DiscoveredSession) {}
        func send(_ message: WireMessage, to peer: PeerHandle) async throws {}
        func disconnect(_ peer: PeerHandle) {}
        func startHeartbeats(sessionID: UUID) {}
        func resume() {}
        func stop() {}
    }

    private func joinPeer(_ coordinator: LocalPlayCoordinator) {
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                   clientID: UUID(), sessionID: nil,
                                                   reconnectToken: nil)), from: peer))
    }

    private func buttonCount(in value: Any) -> Int {
        let count = value is Button<Text> ? 1 : 0
        return count + Mirror(reflecting: value).children.reduce(0) { $0 + buttonCount(in: $1.value) }
    }

    private func texts(in value: Any) -> [String] {
        if let text = value as? Text { return [String(describing: text)] }
        return Mirror(reflecting: value).children.flatMap { texts(in: $0.value) }
    }

    func testClientCanReviewSharedScoreButCannotStartRound() {
        let model = GameViewModel()
        model.phase = .score
        model.score = 87.76
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        coordinator.startBrowsing()
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.welcome(.init(sessionID: UUID(), role: .player2,
                                                    reconnectToken: UUID())), from: peer))
        let view = ScoreView(viewModel: model, coordinator: coordinator)

        XCTAssertEqual(model.score, 87.76)
        XCTAssertFalse(view.showsNewRound)
        XCTAssertEqual(buttonCount(in: view.body), 0)
        XCTAssertTrue(texts(in: view.body).contains { $0.contains("Color Match") })
        XCTAssertTrue(view.pauseStatus?.contains("Paused") == true)
        view.newRound()
        XCTAssertEqual(model.phase, .score)
        XCTAssertEqual(model.score, 87.76)
    }

    func testHostNewRoundIsDisabledWhilePausedAndRoutesThroughCoordinator() throws {
        let model = GameViewModel()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        try coordinator.startHosting()
        joinPeer(coordinator)
        joinPeer(coordinator)

        XCTAssertTrue(coordinator.perform(.startRound))
        model.round?.mix.units = [ColorUnit(color: ColorData.rybPalette[0])]
        XCTAssertTrue(coordinator.perform(.mix))
        XCTAssertTrue(coordinator.perform(.finish))
        let view = ScoreView(viewModel: model, coordinator: coordinator)
        XCTAssertNotNil(model.score)
        XCTAssertTrue(view.showsNewRound)
        XCTAssertEqual(buttonCount(in: view.body), 1)

        coordinator.setPaused(true)
        XCTAssertTrue(view.newRoundDisabled)
        XCTAssertTrue(view.pauseStatus?.contains("Paused") == true)
        view.newRound()
        XCTAssertEqual(model.phase, .score)

        coordinator.setPaused(false)
        XCTAssertFalse(view.newRoundDisabled)
        view.newRound()
        XCTAssertEqual(model.phase, .settings)
        XCTAssertEqual(coordinator.role, .host)
        XCTAssertEqual(coordinator.seatStatus.count, 3)
        model.pauseTimer()
        model.removeKeyMonitor()
    }

    func testSoloNewRoundKeepsOriginalFlow() {
        let model = GameViewModel()
        model.phase = .score
        model.score = 87.76
        let view = ScoreView(viewModel: model)
        XCTAssertTrue(view.showsNewRound)
        XCTAssertFalse(view.newRoundDisabled)
        XCTAssertNil(view.pauseStatus)
        view.newRound()
        XCTAssertEqual(model.phase, .settings)
    }
}
