import XCTest
@testable import ColorGameTesting

@MainActor
final class GameViewModelFlowTests: XCTestCase {
    func testMixRequiresNonemptyUnlockedPlayingMixAndFreezesRound() {
        let viewModel = makePlayingViewModel(.cmyk)
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
        let expected = ColorMixer.blend(units, model: .cmyk)
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

    func testFinishComputesDeltaE2000AndNewRoundResetsAllState() {
        let viewModel = makePlayingViewModel(.cmyk)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        viewModel.pressKey(KeyCode.q.rawValue)
        viewModel.pressMixButton()
        let result = viewModel.mixResult!
        let target = viewModel.round!.request.targetSRGB
        let expectedScore = ScoreCalculator.deltaE2000(
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
        XCTAssertNil(viewModel.selectedModel)
        XCTAssertNil(viewModel.round)
        XCTAssertNil(viewModel.mixResult)
        XCTAssertNil(viewModel.score)
        XCTAssertEqual(viewModel.timerSecondsRemaining, 45)
        XCTAssertFalse(viewModel.canConfirm)
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(viewModel.timerSecondsRemaining, 45)
        viewModel.selectModel(.ryb)
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

        viewModel.selectModel(.ryb)
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

    private func makePlayingViewModel(_ model: ColorModel) -> GameViewModel {
        let viewModel = GameViewModel()
        viewModel.selectModel(model)
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
