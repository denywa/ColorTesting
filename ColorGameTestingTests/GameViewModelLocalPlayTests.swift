import XCTest
@testable import ColorGameTesting

@MainActor
final class GameViewModelLocalPlayTests: XCTestCase {
    func testClientRejectsDirectStateAndSettingsWritesButAppliesHostSnapshot() {
        let host = GameViewModel()

        host.confirmSettings()
        defer { host.pauseTimer(); host.removeKeyMonitor() }
        let client = GameViewModel()
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
        client.applyRemoteState(host.gameState, phase: .playing, timerSecondsRemaining: 12,
                                reassignmentDuration: 30, showTargetColor: true)
        defer { client.pauseTimer(); client.removeKeyMonitor() }

        client.selectMixMode(.auto)
        client.selectedRequestID = ColorData.requestPool[0].id
        client.reassignmentDuration = 90
        client.showTargetColor = false
        client.round = nil
        client.mixResult = SIMD3(1, 0, 0)
        client.score = 100
        client.timerSecondsRemaining = 99
        client.phase = .score

        XCTAssertEqual(client.selectedModel, .ryb)
        XCTAssertNil(client.selectedRequestID)
        XCTAssertEqual(client.reassignmentDuration, 30)
        XCTAssertTrue(client.showTargetColor)
        XCTAssertEqual(client.round?.request.id, host.round?.request.id)
        XCTAssertNil(client.mixResult)
        XCTAssertNil(client.score)
        XCTAssertEqual(client.timerSecondsRemaining, 12)
        XCTAssertEqual(client.phase, .playing)

        host.addColor(player: .player1, slot: .primary)
        host.pressMixButton()
        client.applyRemoteState(host.gameState, phase: .result, timerSecondsRemaining: 11,
                                reassignmentDuration: 45, showTargetColor: false)
        XCTAssertEqual(client.phase, .result)
        XCTAssertEqual(client.timerSecondsRemaining, 11)
        XCTAssertEqual(client.reassignmentDuration, 45)
        XCTAssertFalse(client.showTargetColor)
        XCTAssertEqual(client.mixResult, host.mixResult)
    }

    func testHostPublishesEachMutationAndAcceptsValidatedEarlierColor() {
        let viewModel = GameViewModel()
        var changes = 0
        var inputs: [(PlayerID, ColorSlot)] = []
        viewModel.configureLocalPlay(localPlayer: .player1, isHost: true) { inputs.append(($0, $1)) }
        viewModel.didChange = { changes += 1 }

        viewModel.confirmSettings()
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        XCTAssertEqual(changes, 1)

        viewModel.addColor(player: .player2, slot: .primary)
        viewModel.pressKey(KeyCode.q.rawValue)
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(inputs.first?.0, .player1)
        XCTAssertEqual(inputs.first?.1, .primary)
        XCTAssertTrue(viewModel.round!.mix.units.isEmpty)

        let previousColor = viewModel.round!.assignments[.player2]!.primaryColor
        viewModel.triggerReassignment()
        XCTAssertEqual(changes, 2)
        XCTAssertTrue(viewModel.acceptColor(previousColor, for: .player2))
        XCTAssertEqual(viewModel.round?.mix.units.map(\.color.id), [previousColor.id])
        XCTAssertEqual(changes, 3)
        viewModel.timerTick()
        XCTAssertEqual(changes, 4)
        viewModel.pressMixButton()
        XCTAssertEqual(changes, 5)
        viewModel.selectFinish()
        XCTAssertEqual(changes, 6)
        viewModel.startNewRound()
        XCTAssertEqual(changes, 7)
        XCTAssertEqual(viewModel.phase, .settings)
    }

    func testClientMirrorsRenderStateWithoutRunningRulesOrTimer() {
        let host = GameViewModel()

        host.confirmSettings()
        defer { host.pauseTimer(); host.removeKeyMonitor() }
        let client = GameViewModel()
        var inputs: [(PlayerID, ColorSlot)] = []
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { inputs.append(($0, $1)) }
        client.applyRemoteState(host.gameState, phase: .playing, timerSecondsRemaining: 12,
                                reassignmentDuration: 30, showTargetColor: true)
        defer { client.pauseTimer(); client.removeKeyMonitor() }
        XCTAssertEqual(client.round?.request.id, host.round?.request.id)
        XCTAssertEqual(client.round?.assignments[.player2]?.primaryColor.id,
                       host.round?.assignments[.player2]?.primaryColor.id)
        XCTAssertEqual(client.timerSecondsRemaining, 12)
        XCTAssertTrue(client.showTargetColor)

        client.pressKey(KeyCode.q.rawValue)
        client.addColor(player: .player1, slot: .secondary)
        client.pressKey(KeyCode.b.rawValue)
        client.addColor(player: .player2, slot: .secondary)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(inputs.map(\.0), [.player2, .player2])
        XCTAssertEqual(inputs.map(\.1), [.primary, .secondary])
        XCTAssertTrue(client.round!.mix.units.isEmpty)

        client.timerTick()
        client.triggerReassignment()
        client.startTimer()
        client.pressMixButton()
        client.selectFinish()
        client.confirmSettings()
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(client.phase, .playing)
        XCTAssertEqual(client.timerSecondsRemaining, 12)
        XCTAssertEqual(client.round?.assignments[.player2]?.primaryColor.id,
                       host.round?.assignments[.player2]?.primaryColor.id)
        XCTAssertTrue(client.round!.mix.units.isEmpty)
        XCTAssertNil(client.mixResult)
        XCTAssertNil(client.score)

        host.addColor(player: .player2, slot: .primary)
        host.pressMixButton()
        client.applyRemoteState(host.gameState, phase: .result, timerSecondsRemaining: 11,
                                reassignmentDuration: 30, showTargetColor: true)
        XCTAssertEqual(client.phase, .result)
        XCTAssertEqual(client.mixResult, host.mixResult)
        XCTAssertEqual(client.round?.mix.units.map(\.color.id), host.round?.mix.units.map(\.color.id))
        client.selectRedo()
        XCTAssertEqual(client.phase, .result)
    }
}
