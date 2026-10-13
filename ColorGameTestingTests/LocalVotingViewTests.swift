import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class LocalVotingViewTests: XCTestCase {
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Expected voting snapshot did not arrive")
    }

    private func session(mode: MixMode) async throws -> ([GameViewModel], [LocalPlayCoordinator]) {
        let network = FakePeerNetwork()
        let models = (0..<3).map { _ in GameViewModel() }
        let peers = models.map { LocalPlayCoordinator(viewModel: $0, transport: network.makePeer()) }
        try peers[0].startHosting()
        for index in 1...2 {
            peers[index].startBrowsing()
            peers[index].join(try XCTUnwrap(peers[index].discoveredSessions.first))
            await waitUntil { peers[index].latestSnapshot != nil }
        }
        models[0].selectMixMode(mode)
        XCTAssertTrue(peers[0].perform(.startRound))
        await waitUntil { models.allSatisfy { $0.phase == .playing } }
        models[0].addColor(player: .player1, slot: .primary)
        await waitUntil { models.allSatisfy { $0.round?.mix.units.count == 1 } }
        return (models, peers)
    }

    private func texts(in value: Any) -> [String] {
        if let status = value as? LocalVotingStatusView { return texts(in: status.body) }
        if let text = value as? Text { return [String(describing: text)] }
        return Mirror(reflecting: value).children.flatMap { texts(in: $0.value) }
    }

    private func assertStatus(_ peers: [LocalPlayCoordinator], voter: Int, action: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let statuses = peers.map { LocalVotingStatusView(coordinator: $0).choices }
        XCTAssertTrue(statuses.allSatisfy { $0 == statuses[0] }, file: file, line: line)
        XCTAssertEqual(statuses[0][voter], "Player \(voter + 1): chose \(action) (final)", file: file, line: line)
    }

    func testManualAllRolesVoteOnceKeepColorInputAndShareResultChoices() async throws {
        for voter in 0..<3 {
            let (models, peers) = try await session(mode: .manual)
            defer { peers.forEach { $0.appWillTerminate() } }
            let views = zip(models, peers).map { GameView(viewModel: $0, coordinator: $1) }
            XCTAssertTrue(views.allSatisfy { $0.showsMixButton && $0.canMix })
            views[voter].mix()
            await waitUntil { peers.allSatisfy { $0.voting?.votes.count == 1 } }
            assertStatus(peers, voter: voter, action: "Mix")
            XCTAssertTrue(texts(in: views[voter].body).contains { $0.contains("Two matching votes") })
            XCTAssertFalse(views[voter].canMix, "A final choice disables this ballot")
            XCTAssertTrue(views.allSatisfy { !$0.inputsDisabled })
            XCTAssertTrue(models.allSatisfy { $0.phase == .playing })
            XCTAssertTrue(peers.allSatisfy { $0.voting?.id == peers[0].voting?.id })
            models[voter].addColor(player: PlayerID.allCases[voter], slot: .secondary)
            await waitUntil { models.allSatisfy { $0.round?.mix.units.count == 2 } }
            views[(voter + 1) % 3].mix()
            await waitUntil { models.allSatisfy { $0.phase == .result } }
            let results = zip(models, peers).map { ResultView(viewModel: $0, coordinator: $1) }
            XCTAssertTrue(results.allSatisfy { $0.showsActions && !$0.actionsDisabled })
            results[voter].finish()
            await waitUntil { peers.allSatisfy { $0.voting?.votes.count == 1 } }
            assertStatus(peers, voter: voter, action: "Finish")
            XCTAssertTrue(texts(in: results[voter].body).contains { $0.contains("Two matching votes") })
            XCTAssertTrue(results[voter].actionsDisabled)
            results[(voter + 1) % 3].redo()
            await waitUntil { peers.allSatisfy { $0.voting?.votes.count == 2 } }
            XCTAssertTrue(models.allSatisfy { $0.phase == .result })
            results[(voter + 2) % 3].finish()
            await waitUntil { models.allSatisfy { $0.phase == .score } }
            XCTAssertEqual(models[0].score, models[1].score)
            XCTAssertEqual(models[0].score, models[2].score)
            XCTAssertFalse(ScoreView(viewModel: models[1], coordinator: peers[1]).showsNewRound)
        }
    }

    func testAutoAllRolesCanChooseRedoThenApplyAndPauseBlocksActions() async throws {
        for voter in 0..<3 {
            let (models, peers) = try await session(mode: .auto)
            defer { peers.forEach { $0.appWillTerminate() } }
            let views = zip(models, peers).map { GameView(viewModel: $0, coordinator: $1) }
            XCTAssertTrue(views.allSatisfy { $0.canApply && $0.canRedo && !$0.showsMixButton })
            peers[0].setPaused(true)
            await waitUntil { peers.allSatisfy { $0.paused } }
            XCTAssertTrue(views.allSatisfy { !$0.canApply && !$0.canRedo && $0.inputsDisabled })
            views[voter].apply()
            XCTAssertTrue(peers.allSatisfy { $0.voting?.votes.isEmpty == true })
            peers[0].setPaused(false)
            await waitUntil { peers.allSatisfy { !$0.paused } }
            views[voter].redo()
            await waitUntil { peers.allSatisfy { $0.voting?.votes.count == 1 } }
            assertStatus(peers, voter: voter, action: "Redo")
            XCTAssertFalse(views[voter].canApply)
            XCTAssertFalse(views[voter].canRedo)
            XCTAssertFalse(views[voter].inputsDisabled)
            views[(voter + 1) % 3].redo()
            await waitUntil { models.allSatisfy { $0.round?.mix.units.isEmpty == true } }
            XCTAssertTrue(models.allSatisfy { $0.phase == .playing })
            XCTAssertTrue(views.allSatisfy { !$0.canApply && !$0.canRedo })
            models[voter].addColor(player: PlayerID.allCases[voter], slot: .primary)
            await waitUntil { models.allSatisfy { $0.round?.mix.units.count == 1 } }
            XCTAssertTrue(views[voter].canApply, "New ballot permits a fresh final choice")
            views[voter].apply()
            await waitUntil { peers.allSatisfy { $0.voting?.votes.count == 1 } }
            views[(voter + 1) % 3].apply()
            await waitUntil { models.allSatisfy { $0.phase == .score } }
            XCTAssertEqual(models[0].mixResult, models[1].mixResult)
        }
    }
}
