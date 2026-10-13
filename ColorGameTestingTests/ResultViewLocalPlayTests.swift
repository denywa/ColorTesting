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
        let colors = ColorData.rybPalette
        model.phase = .result
        model.round = Round(
            request: ColorData.requestPool[0], colorModel: .ryb, mixMode: .manual, assignments: [:],
            mix: Mix(units: [ColorUnit(color: colors[0]), ColorUnit(color: colors[1])], isLocked: true)
        )
        model.mixResult = SIMD3(0.2, 0.7, 0.4)
        return model
    }

    @discardableResult
    private func joinPeer(_ coordinator: LocalPlayCoordinator) -> PeerHandle {
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                   clientID: UUID(), sessionID: nil,
                                                   reconnectToken: nil)), from: peer))
        return peer
    }

    private func peerVote(_ action: LocalVoteAction, coordinator: LocalPlayCoordinator,
                          model: GameViewModel, peer: PeerHandle) {
        coordinator.handle(.received(.input(.init(sessionID: coordinator.sessionID!, roundID: model.roundID!,
            actionID: UUID(), action: .vote(action: action, votingID: coordinator.voting!.id))), from: peer))
    }

    private func texts(in value: Any) -> [String] {
        if let heading = value as? PlaytestHeading { return texts(in: heading.body) }
        if let text = value as? Text { return [String(describing: text)] }
        return Mirror(reflecting: value).children.flatMap { texts(in: $0.value) }
    }

    private func buttonCount(in value: Any) -> Int {
        let count = String(describing: Swift.type(of: value)).hasPrefix("Button<") ? 1 : 0
        return count + Mirror(reflecting: value).children.reduce(0) { $0 + buttonCount(in: $1.value) }
    }

    func testClientKeepsResultBreakdownAndDisabledVotingActionsWhilePaused() {
        let model = resultModel()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        coordinator.startBrowsing()
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.welcome(.init(sessionID: UUID(), role: .player2,
                                                    reconnectToken: UUID())), from: peer))
        let view = ResultView(viewModel: model, coordinator: coordinator)

        XCTAssertTrue(view.showsActions)
        XCTAssertEqual(buttonCount(in: view.layoutContent(round: model.round!, result: model.mixResult!, size: CGSize(width: 900, height: 500))), 2)
        XCTAssertTrue(view.actionsDisabled)
        XCTAssertTrue(coordinator.paused)
        XCTAssertTrue(view.pauseStatus?.contains("Paused") == true)
        let visibleText = texts(in: view.layoutContent(round: model.round!, result: model.mixResult!, size: CGSize(width: 900, height: 500)))
        XCTAssertTrue(visibleText.contains { $0.contains("YOUR MIX") })
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
        let peer = joinPeer(coordinator)
        joinPeer(coordinator)

        XCTAssertTrue(coordinator.perform(.startRound))
        model.round?.mix.units = [ColorUnit(color: ColorData.rybPalette[0])]
        XCTAssertTrue(coordinator.castVote(.mix))
        peerVote(.mix, coordinator: coordinator, model: model, peer: peer)
        let view = ResultView(viewModel: model, coordinator: coordinator)
        XCTAssertTrue(view.showsActions)
        XCTAssertEqual(buttonCount(in: view.layoutContent(round: model.round!, result: model.mixResult!, size: CGSize(width: 900, height: 500))), 2)

        coordinator.setPaused(true)
        XCTAssertTrue(view.actionsDisabled)
        XCTAssertTrue(view.pauseStatus?.contains("Paused") == true)
        XCTAssertTrue(texts(in: view.layoutContent(round: model.round!, result: model.mixResult!, size: CGSize(width: 900, height: 500))).contains { $0.contains("YOUR MIX") })
        view.redo()
        view.finish()
        XCTAssertEqual(model.phase, .result)
        XCTAssertNotNil(model.mixResult)

        coordinator.setPaused(false)
        XCTAssertFalse(view.actionsDisabled)
        view.redo()
        XCTAssertEqual(model.phase, .result)
        peerVote(.redo, coordinator: coordinator, model: model, peer: peer)
        XCTAssertEqual(model.phase, .playing)
        XCTAssertTrue(model.round?.mix.units.isEmpty == true)
        model.round?.mix.units = [ColorUnit(color: ColorData.rybPalette[1])]
        XCTAssertTrue(coordinator.castVote(.mix))
        peerVote(.mix, coordinator: coordinator, model: model, peer: peer)
        view.finish()
        XCTAssertEqual(model.phase, .result)
        peerVote(.finish, coordinator: coordinator, model: model, peer: peer)
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
