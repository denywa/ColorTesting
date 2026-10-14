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

    private func buttonCount(in value: Any) -> Int {
        let count = value is Button<Text> ? 1 : 0
        return count + Mirror(reflecting: value).children.reduce(0) { $0 + buttonCount(in: $1.value) }
    }

    private func texts(in value: Any) -> [String] {
        if let heading = value as? PlaytestHeading { return texts(in: heading.body) }
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
        XCTAssertEqual(buttonCount(in: view.layoutContent(score: model.score!, size: CGSize(width: 900, height: 500))), 0)
        XCTAssertTrue(texts(in: view.layoutContent(score: model.score!, size: CGSize(width: 900, height: 500))).contains { $0.contains("MATCH SCORE") })
        XCTAssertTrue(view.pauseStatus?.contains("Paused") == true)
        view.newRound()
        XCTAssertEqual(model.phase, .score)
        XCTAssertEqual(model.score, 87.76)
    }

    func testHostNewRoundIsDisabledWhilePausedAndRoutesThroughCoordinator() throws {
        let model = GameViewModel()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        try coordinator.startHosting()
        let peer = joinPeer(coordinator)
        let thirdPeer = joinPeer(coordinator)

        XCTAssertTrue(coordinator.perform(.startRound))
        model.round?.mix.units = [ColorUnit(color: ColorData.rybPalette[0])]
        XCTAssertTrue(coordinator.castVote(.mix))
        peerVote(.mix, coordinator: coordinator, model: model, peer: peer)
        peerVote(.mix, coordinator: coordinator, model: model, peer: thirdPeer)
        XCTAssertTrue(coordinator.castVote(.finish))
        peerVote(.finish, coordinator: coordinator, model: model, peer: peer)
        let view = ScoreView(viewModel: model, coordinator: coordinator)
        XCTAssertNotNil(model.score)
        XCTAssertTrue(view.showsNewRound)
        XCTAssertEqual(buttonCount(in: view.layoutContent(score: model.score!, size: CGSize(width: 900, height: 500))), 1)

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
