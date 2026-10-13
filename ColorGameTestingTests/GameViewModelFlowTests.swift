import XCTest
@testable import ColorGameTesting

@MainActor
final class GameViewModelFlowTests: XCTestCase {
    func testColorButtonsAddAssignedColorsAndRespectGamePhase() {
        let viewModel = GameViewModel()
        viewModel.addColor(player: .player1, slot: .primary)
        XCTAssertNil(viewModel.round)

        viewModel.confirmSettings()
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }

        let expectedColors = PlayerID.allCases.flatMap { player -> [NamedColor] in
            let assignment = viewModel.round!.assignments[player]!
            return [assignment.primaryColor, assignment.secondaryColor]
        }
        for player in PlayerID.allCases {
            viewModel.addColor(player: player, slot: .primary)
            viewModel.addColor(player: player, slot: .secondary)
        }
        XCTAssertEqual(viewModel.round?.mix.units.map(\.color), expectedColors)

        viewModel.pressMixButton()
        viewModel.addColor(player: .player1, slot: .primary)
        XCTAssertEqual(viewModel.round?.mix.units.count, expectedColors.count)
    }

    func testMixRequiresNonemptyUnlockedPlayingMixAndFreezesRound() {
        let viewModel = makePlayingViewModel(.ryb)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        viewModel.pressMixButton()
        XCTAssertEqual(viewModel.phase, .playing)
        XCTAssertFalse(viewModel.round!.mix.isLocked)
        XCTAssertNil(viewModel.mixResult)

        viewModel.pressKey(KeyCode.q.rawValue)
        viewModel.round?.mix.isLocked = true
        viewModel.pressMixButton()
        XCTAssertEqual(viewModel.phase, .playing)
        XCTAssertNil(viewModel.mixResult)
        viewModel.round?.mix.isLocked = false
        viewModel.pressKey(KeyCode.w.rawValue)
        let units = viewModel.round!.mix.units
        let expected = ColorMixer.blend(units, model: .ryb)
        let originalAssignmentIDs = assignmentIDs(in: viewModel)
        viewModel.timerTick()
        let remaining = viewModel.timerSecondsRemaining
        viewModel.pressMixButton()

        XCTAssertEqual(viewModel.phase, .result)
        XCTAssertTrue(viewModel.round!.mix.isLocked)
        XCTAssertEqual(viewModel.mixResult, expected)
        XCTAssertEqual(viewModel.round!.mix.units.count, units.count)
        viewModel.pressKey(KeyCode.b.rawValue)
        viewModel.timerTick()
        viewModel.triggerReassignment()
        XCTAssertEqual(viewModel.round!.mix.units.count, units.count)
        XCTAssertEqual(viewModel.timerSecondsRemaining, remaining)
        XCTAssertEqual(assignmentIDs(in: viewModel), originalAssignmentIDs)
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(viewModel.timerSecondsRemaining, remaining)
        viewModel.pressMixButton()
        XCTAssertEqual(viewModel.phase, .result)
    }

    func testRedoClearsMixAndResultButPreservesRequestAndCountdownThenResumes() {
        let viewModel = makePlayingViewModel(.ryb)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        viewModel.pressKey(KeyCode.q.rawValue)
        viewModel.timerTick()
        let request = viewModel.round!.request
        let assignments = assignmentIDs(in: viewModel)
        let remaining = viewModel.timerSecondsRemaining
        viewModel.pressMixButton()
        viewModel.selectRedo()

        XCTAssertEqual(viewModel.phase, .playing)
        XCTAssertTrue(viewModel.round!.mix.units.isEmpty)
        XCTAssertTrue(viewModel.round!.mix.ratios.isEmpty)
        XCTAssertFalse(viewModel.round!.mix.isLocked)
        XCTAssertEqual(viewModel.round!.request.id, request.id)
        XCTAssertEqual(viewModel.round!.request.targetSRGB, request.targetSRGB)
        XCTAssertEqual(assignmentIDs(in: viewModel), assignments)
        XCTAssertEqual(viewModel.timerSecondsRemaining, remaining)
        XCTAssertNil(viewModel.mixResult)
        viewModel.pressKey(KeyCode.q.rawValue)
        XCTAssertEqual(viewModel.round!.mix.units.count, 1)
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(viewModel.timerSecondsRemaining, remaining - 1)
    }

    func testFinishComputesMatchPercentageAndNewRoundResetsAllState() {
        let viewModel = GameViewModel()

        viewModel.selectedRequestID = ColorData.requestPool[0].id
        viewModel.confirmSettings()
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        viewModel.pressKey(KeyCode.q.rawValue)
        viewModel.pressMixButton()
        let result = viewModel.mixResult!
        let target = viewModel.round!.request.targetSRGB
        let expectedScore = ScoreCalculator.matchPercentage(
            ColorConverter.sRGBToLab(result), ColorConverter.sRGBToLab(target)
        )
        viewModel.selectFinish()

        XCTAssertEqual(viewModel.phase, .score)
        XCTAssertEqual(viewModel.score!, expectedScore, accuracy: 1e-10)
        XCTAssertTrue(viewModel.round!.mix.isLocked)
        let remaining = viewModel.timerSecondsRemaining
        viewModel.timerTick()
        XCTAssertEqual(viewModel.timerSecondsRemaining, remaining)

        viewModel.startNewRound()
        XCTAssertEqual(viewModel.phase, .settings)
        XCTAssertEqual(viewModel.selectedModel, .ryb)
        XCTAssertEqual(viewModel.selectedMixMode, .manual)
        XCTAssertNil(viewModel.selectedRequestID)
        XCTAssertNil(viewModel.round)
        XCTAssertNil(viewModel.mixResult)
        XCTAssertNil(viewModel.score)
        XCTAssertEqual(viewModel.timerSecondsRemaining, viewModel.reassignmentDuration)
        XCTAssertTrue(viewModel.canConfirm)
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(viewModel.timerSecondsRemaining, viewModel.reassignmentDuration)

        viewModel.confirmSettings()
        XCTAssertEqual(viewModel.phase, .playing)
        XCTAssertEqual(viewModel.round?.colorModel, .ryb)
        XCTAssertTrue(viewModel.round?.mix.units.isEmpty ?? false)
    }

    func testPhaseInappropriateActionsDoNothing() {
        let viewModel = GameViewModel()
        viewModel.pressMixButton()
        viewModel.selectRedo()
        viewModel.selectFinish()
        viewModel.startNewRound()
        XCTAssertEqual(viewModel.phase, .settings)
        XCTAssertNil(viewModel.round)

        viewModel.confirmSettings()
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        viewModel.selectRedo()
        viewModel.selectFinish()
        viewModel.startNewRound()
        XCTAssertEqual(viewModel.phase, .playing)
        XCTAssertNil(viewModel.score)
        viewModel.pressKey(KeyCode.q.rawValue)
        viewModel.pressMixButton()
        viewModel.startNewRound()
        XCTAssertEqual(viewModel.phase, .result)
        viewModel.selectFinish()
        viewModel.selectRedo()
        XCTAssertEqual(viewModel.phase, .score)
    }

    func testAutoApplyScoresLatestBowlDirectlyAndStopsInputAndTimer() throws {
        let model = GameViewModel()
        model.selectMixMode(.auto)
        model.confirmSettings()
        defer { model.endLocalPlay() }
        XCTAssertFalse(model.canMix)
        XCTAssertFalse(model.canApply)
        XCTAssertFalse(model.canRedo)
        model.selectApply()
        model.selectRedo()
        XCTAssertEqual(model.phase, .playing)
        model.pressKey(KeyCode.q.rawValue)
        let firstBlend = model.currentBlend
        model.pressKey(KeyCode.w.rawValue)
        let units = model.round!.mix.units
        let expected = ColorMixer.blend(units, model: .ryb)
        XCTAssertNotEqual(firstBlend, expected)
        XCTAssertTrue(model.canApply)
        XCTAssertTrue(model.canRedo)
        let request = model.round!.request
        let assignments = assignmentIDs(in: model)
        let epoch = model.assignmentEpoch
        model.timerTick()
        let remaining = model.timerSecondsRemaining
        model.selectApply()
        XCTAssertEqual(model.phase, .score)
        XCTAssertTrue(model.canNewRound)
        XCTAssertFalse(model.canApply)
        XCTAssertFalse(model.canRedo)
        XCTAssertNil(model.currentBlend)
        XCTAssertEqual(model.mixResult, expected)
        XCTAssertTrue(model.round!.mix.isLocked)
        XCTAssertEqual(model.round?.request.id, request.id)
        let expectedScore = ScoreCalculator.matchPercentage(
            ColorConverter.sRGBToLab(expected), ColorConverter.sRGBToLab(request.targetSRGB))
        XCTAssertEqual(try XCTUnwrap(model.score), expectedScore, accuracy: 1e-10)
        model.pressKey(KeyCode.b.rawValue)
        model.timerTick()
        model.triggerReassignment()
        model.pressMixButton()
        model.selectFinish()
        model.selectRedo()
        model.selectApply()
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(model.round!.mix.units.map(\.color.id), units.map(\.color.id))
        XCTAssertEqual(assignmentIDs(in: model), assignments)
        XCTAssertEqual(model.assignmentEpoch, epoch)
        XCTAssertEqual(model.timerSecondsRemaining, remaining)
        XCTAssertEqual(model.phase, .score)
    }

    func testAutoRedoClearsColorsAndScoreRetainingRoundAndRunningCountdown() {
        let model = GameViewModel()
        model.selectMixMode(.auto)
        model.confirmSettings()
        defer { model.endLocalPlay() }
        model.pressKey(KeyCode.q.rawValue)
        model.timerTick()
        let request = model.round!.request
        let assignments = assignmentIDs(in: model)
        let remaining = model.timerSecondsRemaining
        let roundID = model.roundID
        let epoch = model.assignmentEpoch
        model.mixResult = SIMD3(0.1, 0.2, 0.3)
        model.score = 12
        model.selectRedo()
        XCTAssertEqual(model.phase, .playing)
        XCTAssertTrue(model.round!.mix.units.isEmpty)
        XCTAssertFalse(model.round!.mix.isLocked)
        XCTAssertNil(model.currentBlend)
        XCTAssertNil(model.mixResult)
        XCTAssertNil(model.score)
        XCTAssertEqual(model.round?.request.id, request.id)
        XCTAssertEqual(model.round?.request.targetSRGB, request.targetSRGB)
        XCTAssertEqual(model.round?.mixMode, .auto)
        XCTAssertEqual(model.roundID, roundID)
        XCTAssertEqual(model.assignmentEpoch, epoch)
        XCTAssertEqual(assignmentIDs(in: model), assignments)
        XCTAssertEqual(model.timerSecondsRemaining, remaining)
        XCTAssertFalse(model.canApply)
        XCTAssertFalse(model.canRedo)
        model.pressKey(KeyCode.w.rawValue)
        XCTAssertEqual(model.round?.mix.units.count, 1)
        XCTAssertNotNil(model.currentBlend)
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(model.timerSecondsRemaining, remaining - 1)
    }

    func testActionEligibilityAndInvalidActionsDependOnlyOnDomainState() {
        for mode in MixMode.allCases {
            for phase in [GamePhase.settings, .playing, .result, .score] {
                for locked in [false, true] {
                    for empty in [false, true] {
                        for hasResult in [false, true] {
                            let model = GameViewModel()
                            model.selectMixMode(mode)
                            model.confirmSettings()
                            model.pauseTimer()
                            defer { model.endLocalPlay() }
                            if !empty { model.addColor(player: .player1, slot: .primary) }
                            model.round?.mix.isLocked = locked
                            model.phase = phase
                            model.mixResult = hasResult ? SIMD3(0.1, 0.2, 0.3) : nil
                            model.configureLocalPlay(localPlayer: .player1, isHost: true) { _, _ in }
                            let mix = mode == .manual && phase == .playing && !locked && !empty
                            let apply = mode == .auto && phase == .playing && !locked && !empty
                            let redo = (mode == .manual && phase == .result && locked) || apply
                            let finish = mode == .manual && phase == .result && locked && hasResult
                            let newRound = phase == .score
                            XCTAssertEqual(model.canMix, mix)
                            XCTAssertEqual(model.canApply, apply)
                            XCTAssertEqual(model.canRedo, redo)
                            XCTAssertEqual(model.canFinish, finish)
                            XCTAssertEqual(model.canNewRound, newRound)
                            var publications = 0
                            model.didChange = { publications += 1 }
                            if !mix { model.pressMixButton() }
                            if !apply { model.selectApply() }
                            if !redo { model.selectRedo() }
                            if !finish { model.selectFinish() }
                            if !newRound { model.startNewRound() }
                            XCTAssertEqual(publications, 0)
                            XCTAssertEqual(model.phase, phase)
                            XCTAssertEqual(model.round?.mix.units.isEmpty, empty)
                            XCTAssertEqual(model.round?.mix.isLocked, locked)
                            XCTAssertEqual(model.mixResult != nil, hasResult)
                            let state = model.gameState
                            let client = GameViewModel()
                            defer { client.endLocalPlay() }
                            client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
                            client.applyRemoteState(state, phase: phase, timerSecondsRemaining: 17,
                                                    reassignmentDuration: 30, showTargetColor: true)
                            XCTAssertEqual(client.canMix, mix)
                            XCTAssertEqual(client.canApply, apply)
                            XCTAssertEqual(client.canRedo, redo)
                            XCTAssertEqual(client.canFinish, finish)
                            XCTAssertEqual(client.canNewRound, newRound)
                            client.pressMixButton()
                            client.selectApply()
                            client.selectRedo()
                            client.selectFinish()
                            client.startNewRound()
                            XCTAssertEqual(client.phase, phase)
                            XCTAssertEqual(client.round?.mix.units.isEmpty, empty)
                            XCTAssertEqual(client.round?.mix.isLocked, locked)
                            XCTAssertEqual(client.mixResult, state.mixResult)
                            XCTAssertEqual(client.currentBlend, state.currentBlend)
                            XCTAssertEqual(client.score, state.score)
                            XCTAssertEqual(client.timerSecondsRemaining, 17)
                        }
                    }
                }
            }
        }
        let absentRound = GameViewModel()
        absentRound.phase = .playing
        XCTAssertFalse(absentRound.canMix)
        XCTAssertFalse(absentRound.canApply)
        XCTAssertFalse(absentRound.canRedo)
        XCTAssertFalse(absentRound.canFinish)
        XCTAssertFalse(absentRound.canNewRound)
    }

    func testHostAutoActionsPublishOnlyAcceptedTransitionsAndNewRoundRetainsSettings() {
        let suite = "AutoActions-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = GameViewModel(requestDefaults: defaults)
        defer { model.endLocalPlay() }
        XCTAssertTrue(model.addCustomRequest(text: "Retained target", hex: "#123456"))
        let requests = model.availableRequests.map(\.id)
        model.reassignmentDuration = 90
        model.showTargetColor = true
        model.selectMixMode(.auto)
        model.confirmSettings()
        model.configureLocalPlay(localPlayer: .player1, isHost: true) { _, _ in }
        var phases: [GamePhase] = []
        model.didChange = { phases.append(model.phase) }
        model.selectApply()
        model.selectRedo()
        XCTAssertTrue(phases.isEmpty)
        XCTAssertTrue(model.acceptColor(ColorData.rybPalette[0], for: .player2))
        model.pressMixButton()
        model.selectFinish()
        XCTAssertEqual(phases, [.playing])
        model.selectRedo()
        XCTAssertEqual(phases, [.playing, .playing])
        XCTAssertTrue(model.acceptColor(ColorData.rybPalette[1], for: .player2))
        model.selectApply()
        model.selectApply()
        XCTAssertEqual(phases, [.playing, .playing, .playing, .score])
        model.startNewRound()
        model.startNewRound()
        XCTAssertEqual(phases, [.playing, .playing, .playing, .score, .settings])
        XCTAssertNil(model.round)
        XCTAssertNil(model.roundID)
        XCTAssertNil(model.assignmentEpoch)
        XCTAssertNil(model.selectedRequestID)
        XCTAssertNil(model.currentBlend)
        XCTAssertNil(model.mixResult)
        XCTAssertNil(model.score)
        XCTAssertEqual(model.selectedMixMode, .manual)
        XCTAssertEqual(model.selectedModel, .ryb)
        XCTAssertEqual(model.reassignmentDuration, 90)
        XCTAssertEqual(model.timerSecondsRemaining, 90)
        XCTAssertTrue(model.showTargetColor)
        XCTAssertEqual(model.availableRequests.map(\.id), requests)
    }

    private func makePlayingViewModel(_ model: ColorModel) -> GameViewModel {
        let viewModel = GameViewModel()

        viewModel.confirmSettings()
        return viewModel
    }

    private func assignmentIDs(in viewModel: GameViewModel) -> [UUID] {
        PlayerID.allCases.flatMap { player in
            let assignment = viewModel.round!.assignments[player]!
            return [assignment.primaryColor.id, assignment.secondaryColor.id]
        }
    }
}
