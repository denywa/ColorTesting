import XCTest
@testable import ColorGameTesting

@MainActor
final class LocalPlayInputIntegrationTests: XCTestCase {
    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Expected shared game state did not arrive")
    }

    func testLocalButtonsKeyboardMixAndPauseUseOneHostMix() async throws {
        let network = FakePeerNetwork()
        let models = (0..<3).map { _ in
            GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        }
        let peers = models.map { LocalPlayCoordinator(viewModel: $0, transport: network.makePeer()) }
        defer { peers.forEach { $0.appWillTerminate() } }

        try peers[0].startHosting()
        for index in 1...2 {
            peers[index].startBrowsing()
            peers[index].join(try XCTUnwrap(peers[index].discoveredSessions.first))
            await waitUntil { peers[index].role != nil && peers[index].latestSnapshot != nil }
        }

        XCTAssertTrue(peers[0].perform(.startRound))
        await waitUntil { models[1].phase == .playing && models[2].phase == .playing }

        let views = zip(models, peers).map { GameView(viewModel: $0.0, coordinator: $0.1) }
        XCTAssertEqual(views.map(\.visiblePlayers), [[.player1], [.player2], [.player3]])
        XCTAssertFalse(views[1].showsMixButton)
        XCTAssertFalse(views[2].showsMixButton)
        XCTAssertFalse(views[0].canMix)
        XCTAssertFalse(peers[1].perform(.mix))

        let expected = [
            try XCTUnwrap(models[0].round?.assignments[.player1]?.primaryColor.id),
            try XCTUnwrap(models[1].round?.assignments[.player2]?.secondaryColor.id),
            try XCTUnwrap(models[2].round?.assignments[.player3]?.primaryColor.id)
        ]
        models[0].addColor(player: .player1, slot: .primary) // iOS button path
        models[1].pressKey(KeyCode.n.rawValue) // macOS local key path
        models[2].addColor(player: .player3, slot: .primary) // iOS button path
        XCTAssertTrue(models[1].round?.mix.units.isEmpty == true)
        XCTAssertTrue(models[2].round?.mix.units.isEmpty == true)
        await waitUntil { models.allSatisfy { $0.round?.mix.units.count == 3 } }
        let hostColors = try XCTUnwrap(models[0].round?.mix.units.map(\.color.id))
        XCTAssertEqual(hostColors.first, expected[0])
        XCTAssertEqual(hostColors.map(\.uuidString).sorted(), expected.map(\.uuidString).sorted())
        for model in models.dropFirst() {
            XCTAssertEqual(model.round?.mix.units.map(\.color.id), hostColors)
        }

        models[1].pressKey(KeyCode.q.rawValue) // another player's key is ignored
        models[2].addColor(player: .player2, slot: .primary)
        XCTAssertEqual(models[0].round?.mix.units.count, 3)

        peers[0].setPaused(true)
        await waitUntil { peers[1].paused && peers[2].paused }
        XCTAssertTrue(views.allSatisfy(\.inputsDisabled))
        XCTAssertFalse(views[0].canMix)
        models[0].addColor(player: .player1, slot: .secondary)
        models[1].pressKey(KeyCode.b.rawValue)
        models[2].addColor(player: .player3, slot: .secondary)
        views[0].mix()
        XCTAssertEqual(models[0].round?.mix.units.count, 3)
        XCTAssertEqual(models[0].phase, .playing)

        peers[0].setPaused(false)
        await waitUntil { !peers[1].paused && !peers[2].paused }
        XCTAssertTrue(views[0].canMix)
        views[0].mix()
        await waitUntil { models.allSatisfy { $0.phase == .result } }
        XCTAssertEqual(models[0].round?.mix.units.map(\.color.id), hostColors)
        XCTAssertEqual(models[1].mixResult, models[0].mixResult)
        XCTAssertEqual(models[2].mixResult, models[0].mixResult)
        XCTAssertFalse(peers[1].perform(.mix))
        XCTAssertFalse(peers[2].perform(.mix))
    }
}
