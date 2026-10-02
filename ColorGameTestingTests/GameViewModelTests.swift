import XCTest
@testable import ColorGameTesting

@MainActor
final class GameViewModelTests: XCTestCase {
    func testModelSelectionGatesConfirmationAndIsMutuallyExclusive() {
        let viewModel = GameViewModel()
        XCTAssertEqual(viewModel.phase, .settings)
        XCTAssertNil(viewModel.selectedModel)
        XCTAssertFalse(viewModel.canConfirm)

        viewModel.confirmSettings()
        XCTAssertEqual(viewModel.phase, .settings)

        viewModel.selectModel(.cmyk)
        XCTAssertEqual(viewModel.selectedModel, .cmyk)
        XCTAssertTrue(viewModel.canConfirm)
        viewModel.selectModel(.ryb)
        XCTAssertEqual(viewModel.selectedModel, .ryb)
        XCTAssertTrue(viewModel.canConfirm)
    }

    func testRoundStartsWithPoolRequestEmptyMixAndModelPaletteAssignments() {
        for model in ColorModel.allCases {
            let viewModel = GameViewModel()
            defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
            viewModel.selectModel(model)
            viewModel.confirmSettings()

            XCTAssertEqual(viewModel.phase, .playing)
            XCTAssertEqual(viewModel.selectedModel, model)
            XCTAssertEqual(viewModel.round?.colorModel, model)
            XCTAssertEqual(viewModel.gameState.round?.request.id, viewModel.round?.request.id)
            XCTAssertTrue(ColorData.requestPool.contains { $0.id == viewModel.round?.request.id })
            XCTAssertEqual(viewModel.round?.assignments.count, PlayerID.allCases.count)
            XCTAssertEqual(viewModel.round?.mix.units.count, 0)
            XCTAssertTrue(viewModel.round?.mix.ratios.isEmpty ?? false)
            XCTAssertFalse(viewModel.round?.mix.isLocked ?? true)
            XCTAssertEqual(viewModel.timerSecondsRemaining, 45)
            XCTAssertNil(viewModel.mixResult)
            XCTAssertNil(viewModel.score)
            assertAssignmentsBelongToPalette(viewModel)
        }
    }

    func testIndependentColorDrawsAllowDuplicatesWithinAssignments() {
        let viewModel = makePlayingViewModel(.cmyk)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        var sawDuplicate = false
        for _ in 0..<100 {
            if let assignments = viewModel.round?.assignments.values {
                sawDuplicate = sawDuplicate || assignments.contains { $0.primaryColor.id == $0.secondaryColor.id }
            }
            viewModel.triggerReassignment()
            assertAssignmentsBelongToPalette(viewModel)
        }
        XCTAssertTrue(sawDuplicate, "Independent draws must permit the same color in both slots")
    }

    func testEveryMappedKeyAddsOneCurrentColorAndUpdatesRatios() {
        let viewModel = makePlayingViewModel(.ryb)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        let mapping: [(UInt16, PlayerID, ColorSlot)] = [
            (KeyCode.q.rawValue, .player1, .primary),
            (KeyCode.w.rawValue, .player1, .secondary),
            (KeyCode.b.rawValue, .player2, .primary),
            (KeyCode.n.rawValue, .player2, .secondary),
            (KeyCode.o.rawValue, .player3, .primary),
            (KeyCode.p.rawValue, .player3, .secondary)
        ]
        for (keyCode, player, slot) in mapping {
            guard let assignment = viewModel.round?.assignments[player] else {
                XCTFail("Missing assignment for \(player)")
                return
            }
            let expected = slot == .primary ? assignment.primaryColor : assignment.secondaryColor
            let before = viewModel.round!.mix.units.count
            viewModel.pressKey(keyCode)
            XCTAssertEqual(viewModel.round?.mix.units.count, before + 1)
            XCTAssertEqual(viewModel.round?.mix.units.last?.color.id, expected.id)
            XCTAssertEqual(viewModel.round!.mix.ratios.values.reduce(0, +), 1, accuracy: 1e-9)
        }
        let count = viewModel.round!.mix.units.count
        viewModel.pressKey(0)
        XCTAssertEqual(viewModel.round?.mix.units.count, count)

        viewModel.round!.mix.isLocked = true
        for (keyCode, _, _) in mapping { viewModel.pressKey(keyCode) }
        XCTAssertEqual(viewModel.round?.mix.units.count, count)
    }

    func testTimerReassignsAtZeroAndPreservesMixAndResetsCountdown() {
        let viewModel = makePlayingViewModel(.cmyk)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        viewModel.pauseTimer()
        viewModel.pressKey(KeyCode.q.rawValue)
        viewModel.pressKey(KeyCode.b.rawValue)
        let originalUnits = viewModel.round!.mix.units.map(\.color.id)
        let originalRatios = viewModel.round!.mix.ratios

        for expected in stride(from: 44, through: 1, by: -1) {
            viewModel.timerTick()
            XCTAssertEqual(viewModel.timerSecondsRemaining, expected)
        }
        viewModel.timerTick()
        XCTAssertEqual(viewModel.timerSecondsRemaining, 45)
        XCTAssertEqual(viewModel.round!.mix.units.map(\.color.id), originalUnits)
        XCTAssertEqual(viewModel.round!.mix.ratios, originalRatios)
        assertAssignmentsBelongToPalette(viewModel)
        let currentPrimary = viewModel.round!.assignments[.player1]!.primaryColor.id
        viewModel.pressKey(KeyCode.q.rawValue)
        XCTAssertEqual(viewModel.round!.mix.units.last?.color.id, currentPrimary)
    }

    func testPausedTimerDoesNotCountDownUntilResumed() {
        let viewModel = makePlayingViewModel(.ryb)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        viewModel.pauseTimer()
        let initial = viewModel.timerSecondsRemaining
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(viewModel.timerSecondsRemaining, initial)
        viewModel.resumeTimer()
        RunLoop.main.run(until: Date().addingTimeInterval(1.1))
        XCTAssertEqual(viewModel.timerSecondsRemaining, initial - 1)
    }

    func testDeinitReleasesViewModelWithActiveTimerAndKeyMonitor() {
        weak var releasedViewModel: GameViewModel?
        do {
            let viewModel = makePlayingViewModel(.cmyk)
            releasedViewModel = viewModel
            XCTAssertNotNil(releasedViewModel)
        }
        XCTAssertNil(releasedViewModel)
    }

    private func makePlayingViewModel(_ model: ColorModel) -> GameViewModel {
        let viewModel = GameViewModel()
        viewModel.selectModel(model)
        viewModel.confirmSettings()
        return viewModel
    }

    private func assertAssignmentsBelongToPalette(_ viewModel: GameViewModel,
                                                  file: StaticString = #filePath, line: UInt = #line) {
        guard let round = viewModel.round else {
            XCTFail("Missing round", file: file, line: line)
            return
        }
        let ids = Set(ColorData.colors(for: round.colorModel).map(\.id))
        for player in PlayerID.allCases {
            guard let assignment = round.assignments[player] else {
                XCTFail("Missing assignment for \(player)", file: file, line: line)
                continue
            }
            XCTAssertEqual(assignment.player, player, file: file, line: line)
            XCTAssertTrue(ids.contains(assignment.primaryColor.id), file: file, line: line)
            XCTAssertTrue(ids.contains(assignment.secondaryColor.id), file: file, line: line)
        }
    }
}
