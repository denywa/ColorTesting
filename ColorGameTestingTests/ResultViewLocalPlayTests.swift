import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class ResultViewLocalPlayTests: XCTestCase {
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

    private func resultModel() -> GameViewModel {
        let model = GameViewModel()
        let colors = ColorData.cmykPalette
        model.phase = .result
        model.round = Round(
            request: ColorData.requestPool[0], colorModel: .cmyk, assignments: [:],
            mix: Mix(units: [ColorUnit(color: colors[0]), ColorUnit(color: colors[1])], isLocked: true)
        )
        model.mixResult = SIMD3(0.2, 0.7, 0.4)
        return model
    }

    private func joinPeer(_ coordinator: LocalPlayCoordinator) {
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                   clientID: UUID(), sessionID: nil,
                                                   reconnectToken: nil)), from: peer))
    }

    private func texts(in value: Any) -> [String] {
        if let text = value as? Text { return [String(describing: text)] }
        return Mirror(reflecting: value).children.flatMap { texts(in: $0.value) }
    }

    private func buttonCount(in value: Any) -> Int {
        let count = value is Button<Text> ? 1 : 0
        return count + Mirror(reflecting: value).children.reduce(0) { $0 + buttonCount(in: $1.value) }
    }

    func testClientKeepsResultAndBreakdownWithoutHostActionsWhilePaused() {
        let model = resultModel()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        coordinator.startBrowsing()
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.welcome(.init(sessionID: UUID(), role: .player2,
                                                    reconnectToken: UUID())), from: peer))
        let view = ResultView(viewModel: model, coordinator: coordinator)

        XCTAssertFalse(view.showsActions)
        XCTAssertEqual(buttonCount(in: view.body), 0)
        XCTAssertTrue(coordinator.paused)
        XCTAssertTrue(view.pauseStatus?.contains("Paused") == true)
        let visibleText = texts(in: view.body)
        XCTAssertTrue(visibleText.contains { $0.contains("Your Mix") })
        XCTAssertTrue(visibleText.contains { $0.contains("Color Breakdown") })
        XCTAssertEqual(ResultView.breakdown(for: model.round!.mix).map(\.count), [1, 1])
        XCTAssertEqual(model.mixResult, SIMD3(0.2, 0.7, 0.4))
        view.redo()
        view.finish()
        XCTAssertEqual(model.phase, .result)
    }

    func testHostActionsAreBlockedDuringPauseAndUseCoordinatorWhenResumed() throws {
        let model = GameViewModel()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        try coordinator.startHosting()
        joinPeer(coordinator)
        joinPeer(coordinator)
        model.selectModel(.cmyk)
        XCTAssertTrue(coordinator.perform(.startRound))
        model.round?.mix.units = [ColorUnit(color: ColorData.cmykPalette[0])]
        XCTAssertTrue(coordinator.perform(.mix))
        let view = ResultView(viewModel: model, coordinator: coordinator)
        XCTAssertTrue(view.showsActions)
        XCTAssertEqual(buttonCount(in: view.body), 2)

        coordinator.setPaused(true)
        XCTAssertTrue(view.actionsDisabled)
        XCTAssertTrue(view.pauseStatus?.contains("Paused") == true)
        XCTAssertTrue(texts(in: view.body).contains { $0.contains("Color Breakdown") })
        view.redo()
        view.finish()
        XCTAssertEqual(model.phase, .result)
        XCTAssertNotNil(model.mixResult)

        coordinator.setPaused(false)
        XCTAssertFalse(view.actionsDisabled)
        view.redo()
        XCTAssertEqual(model.phase, .playing)
        XCTAssertTrue(model.round?.mix.units.isEmpty == true)
        model.round?.mix.units = [ColorUnit(color: ColorData.cmykPalette[1])]
        XCTAssertTrue(coordinator.perform(.mix))
        view.finish()
        XCTAssertEqual(model.phase, .score)
        XCTAssertNotNil(model.score)
        model.pauseTimer()
        model.removeKeyMonitor()
    }

    func testSoloActionsStillUseOriginalFlow() {
        let redoModel = resultModel()
        let redoView = ResultView(viewModel: redoModel)
        XCTAssertTrue(redoView.showsActions)
        XCTAssertFalse(redoView.actionsDisabled)
        XCTAssertNil(redoView.pauseStatus)
        redoView.redo()
        XCTAssertEqual(redoModel.phase, .playing)

        let finishModel = resultModel()
        ResultView(viewModel: finishModel).finish()
        XCTAssertEqual(finishModel.phase, .score)
        XCTAssertNotNil(finishModel.score)
    }
}
