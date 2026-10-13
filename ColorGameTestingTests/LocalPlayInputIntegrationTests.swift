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

    private func firstColorOrder(_ colors: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return colors.filter { seen.insert($0).inserted }
    }

    private func assertSharedMix(_ client: GameViewModel, matches host: GameViewModel,
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        let hostMix = try XCTUnwrap(host.round?.mix, file: file, line: line)
        let clientMix = try XCTUnwrap(client.round?.mix, file: file, line: line)
        let hostColors = hostMix.units.map(\.color.id)
        let clientColors = clientMix.units.map(\.color.id)
        XCTAssertEqual(Dictionary(grouping: clientColors, by: { $0 }).mapValues(\.count),
                       Dictionary(grouping: hostColors, by: { $0 }).mapValues(\.count), file: file, line: line)
        XCTAssertEqual(clientMix.ratios, hostMix.ratios, file: file, line: line)
        // Compressed snapshots preserve first appearances, rather than every repeated unit's position.
        XCTAssertEqual(firstColorOrder(clientColors), firstColorOrder(hostColors), file: file, line: line)
    }

    func testRepeatedColorContributionsPreserveCountsRatiosAndFirstColorOrder() async throws {
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
        await waitUntil { models.allSatisfy { $0.phase == .playing } }

        let inputs = try PlayerID.allCases.enumerated().flatMap { index, player in
            let assignment = try XCTUnwrap(models[index].round?.assignments[player])
            return [(index: index, player: player, slot: ColorSlot.primary, color: assignment.primaryColor.id),
                    (index: index, player: player, slot: ColorSlot.secondary, color: assignment.secondaryColor.id)]
        }
        let repeated = try XCTUnwrap(Dictionary(grouping: inputs, by: \.color).values.first { $0.count == 2 })
        XCTAssertNotEqual(repeated[0].player, repeated[1].player)
        let third = try XCTUnwrap(inputs.first { input in
            !repeated.contains { $0.player == input.player } && input.color != repeated[0].color
        })
        let contributions = repeated + [third]
        for (count, input) in contributions.enumerated() {
            models[input.index].addColor(player: input.player, slot: input.slot)
            await waitUntil { models.allSatisfy { $0.round?.mix.units.count == count + 1 } }
        }

        let hostColors = try XCTUnwrap(models[0].round?.mix.units.map(\.color.id))
        XCTAssertEqual(hostColors, contributions.map(\.color))
        XCTAssertEqual(hostColors[0], hostColors[1])
        XCTAssertNotEqual(hostColors[1], hostColors[2])
        for model in models.dropFirst() {
            try assertSharedMix(model, matches: models[0])
        }
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
        XCTAssertTrue(views[1].showsMixButton)
        XCTAssertTrue(views[2].showsMixButton)
        XCTAssertFalse(views[0].canMix)
        XCTAssertFalse(peers[1].castVote(.mix))

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
            try assertSharedMix(model, matches: models[0])
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
        XCTAssertEqual(models[0].phase, .playing)
        await waitUntil { peers[1].voting?.votes.count == 1 }
        XCTAssertTrue(peers[1].castVote(.mix))
        await waitUntil { models.allSatisfy { $0.phase == .result } }
        XCTAssertEqual(models[0].round?.mix.units.map(\.color.id), hostColors)
        XCTAssertEqual(models[1].mixResult, models[0].mixResult)
        XCTAssertEqual(models[2].mixResult, models[0].mixResult)
        XCTAssertFalse(peers[1].castVote(.mix))
        XCTAssertFalse(peers[2].castVote(.mix))
    }
}
