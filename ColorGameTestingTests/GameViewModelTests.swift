import XCTest
@testable import ColorGameTesting

@MainActor
final class GameViewModelTests: XCTestCase {
    func testDefaultsStartWithoutModelSelection() {
        let viewModel = GameViewModel()
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        XCTAssertEqual(viewModel.phase, .settings)
        XCTAssertEqual(viewModel.selectedModel, .ryb)
        XCTAssertTrue(viewModel.canConfirm)
        XCTAssertEqual(viewModel.reassignmentDuration, 45)
        XCTAssertFalse(viewModel.showTargetColor)
        viewModel.confirmSettings()
        XCTAssertEqual(viewModel.phase, .playing)
        XCTAssertEqual(viewModel.round?.colorModel, .ryb)
    }

    func testSelectedModeIsCapturedAndCannotChangeDuringRound() {
        for mode in MixMode.allCases {
            let viewModel = GameViewModel()
            defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
            XCTAssertEqual(viewModel.selectedMixMode, .manual)
            viewModel.selectMixMode(mode)
            XCTAssertEqual(viewModel.selectedMixMode, mode)
            viewModel.confirmSettings()
            XCTAssertEqual(viewModel.round?.mixMode, mode)
            viewModel.selectMixMode(mode == .auto ? .manual : .auto)
            XCTAssertEqual(viewModel.selectedMixMode, mode)
            XCTAssertEqual(viewModel.round?.mixMode, mode)
            XCTAssertFalse(viewModel.canConfirm)
        }
    }

    func testMixModeSelectionRequiresSettingsAuthorityAndNotifiesOnce() {
        let host = GameViewModel()
        host.configureLocalPlay(localPlayer: .player1, isHost: true) { _, _ in }
        var changes = 0
        host.didChange = { changes += 1 }
        host.selectMixMode(.auto)
        host.selectMixMode(.auto)
        XCTAssertEqual(host.selectedMixMode, .auto)
        XCTAssertEqual(changes, 1)
        host.phase = .score
        host.selectMixMode(.manual)
        XCTAssertEqual(host.selectedMixMode, .auto)
        XCTAssertEqual(changes, 1)
        let client = GameViewModel()
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
        client.selectMixMode(.auto)
        XCTAssertEqual(client.selectedMixMode, .manual)
        XCTAssertFalse(client.canConfirm)
    }

    func testNewRoundResetsEitherModeAndRetainsSettingsAndCatalog() {
        let suite = "RoundModeReset-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for mode in MixMode.allCases {
            let viewModel = GameViewModel(requestDefaults: defaults)
            defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
            XCTAssertTrue(viewModel.addCustomRequest(text: "Saved target", hex: "#123456"))
            let requests = viewModel.availableRequests.map(\.id)
            viewModel.reassignmentDuration = 90
            viewModel.showTargetColor = true
            viewModel.selectMixMode(mode)
            viewModel.confirmSettings()
            viewModel.addColor(player: .player1, slot: .primary)
            if mode == .manual {
                viewModel.pressMixButton()
                XCTAssertEqual(viewModel.phase, .result)
                viewModel.selectFinish()
            } else {
                viewModel.selectApply()
            }
            XCTAssertEqual(viewModel.phase, .score)
            XCTAssertTrue(viewModel.round?.mix.isLocked == true)
            XCTAssertNotNil(viewModel.mixResult)
            XCTAssertNotNil(viewModel.score)
            viewModel.startNewRound()
            XCTAssertEqual(viewModel.phase, .settings)
            XCTAssertEqual(viewModel.selectedModel, .ryb)
            XCTAssertEqual(viewModel.selectedMixMode, .manual)
            XCTAssertNil(viewModel.round)
            XCTAssertNil(viewModel.roundID)
            XCTAssertNil(viewModel.assignmentEpoch)
            XCTAssertNil(viewModel.selectedRequestID)
            XCTAssertNil(viewModel.currentBlend)
            XCTAssertNil(viewModel.mixResult)
            XCTAssertNil(viewModel.score)
            XCTAssertEqual(viewModel.reassignmentDuration, 90)
            XCTAssertEqual(viewModel.timerSecondsRemaining, 90)
            XCTAssertTrue(viewModel.showTargetColor)
            XCTAssertEqual(viewModel.availableRequests.map(\.id), requests)
            XCTAssertTrue(viewModel.canConfirm)
        }
    }

    func testRoundStartsWithAvailableRequestEmptyMixAndModelPaletteAssignments() {
        for model in ColorModel.allCases {
            let viewModel = GameViewModel()
            defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
            XCTAssertNil(viewModel.selectedRequestID)

            viewModel.confirmSettings()

            XCTAssertEqual(viewModel.phase, .playing)
            XCTAssertEqual(viewModel.selectedModel, model)
            XCTAssertEqual(viewModel.round?.colorModel, model)
            XCTAssertEqual(viewModel.gameState.round?.request.id, viewModel.round?.request.id)
            XCTAssertTrue(viewModel.availableRequests.contains { $0.id == viewModel.round?.request.id })
            XCTAssertEqual(viewModel.round?.assignments.count, PlayerID.allCases.count)
            XCTAssertEqual(viewModel.round?.mix.units.count, 0)
            XCTAssertTrue(viewModel.round?.mix.ratios.isEmpty ?? false)
            XCTAssertFalse(viewModel.round?.mix.isLocked ?? true)
            XCTAssertEqual(viewModel.timerSecondsRemaining, viewModel.reassignmentDuration)
            XCTAssertNil(viewModel.mixResult)
            XCTAssertNil(viewModel.score)
            assertAssignmentsContainFullPalettePlusOneDuplicate(viewModel)
        }
    }

    func testSelectedRequestIsUsedForTheRound() {
        for request in ColorData.requestPool {
            let viewModel = GameViewModel()

            viewModel.selectedRequestID = request.id
            viewModel.confirmSettings()

            XCTAssertEqual(viewModel.round?.request.id, request.id)
            XCTAssertEqual(viewModel.round?.request.text, request.text)
            XCTAssertEqual(viewModel.round?.request.targetSRGB, request.targetSRGB)
            viewModel.pauseTimer()
            viewModel.removeKeyMonitor()
        }
    }

    func testFivePaletteColorsAndOneDuplicateAtStartAndEveryReassignment() {
        for mode in MixMode.allCases {
            for _ in 0..<20 {
                let viewModel = GameViewModel()
                defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
                viewModel.selectMixMode(mode)
                viewModel.confirmSettings()
                assertAssignmentsContainFullPalettePlusOneDuplicate(viewModel)
                for _ in 0..<5 {
                    viewModel.triggerReassignment()
                    assertAssignmentsContainFullPalettePlusOneDuplicate(viewModel)
                }
            }
        }
    }

    func testDuplicatedPairIsCorrectedForEveryPlayerAndPaletteColor() {
        let palette = ColorData.rybPalette
        for duplicate in palette {
            for playerIndex in PlayerID.allCases.indices {
                var slots = palette.filter { $0.id != duplicate.id }
                slots.insert(contentsOf: [duplicate, duplicate], at: 2 * playerIndex)
                var expected = slots
                expected.swapAt(2 * playerIndex + 1, (2 * playerIndex + 2) % slots.count)

                let assignments = GameViewModel.assignments(from: slots)

                assertAssignmentsContainFullPalettePlusOneDuplicate(assignments)
                for (index, player) in PlayerID.allCases.enumerated() {
                    XCTAssertEqual(assignments[player]?.primaryColor.id, expected[2 * index].id)
                    XCTAssertEqual(assignments[player]?.secondaryColor.id, expected[2 * index + 1].id)
                }
            }
        }
    }

    func testAlreadyDistinctPairsKeepTheirShuffledOrder() {
        let palette = ColorData.rybPalette
        let slots = palette + [palette[0]]
        let assignments = GameViewModel.assignments(from: slots)
        assertAssignmentsContainFullPalettePlusOneDuplicate(assignments)
        for (index, player) in PlayerID.allCases.enumerated() {
            XCTAssertEqual(assignments[player]?.primaryColor.id, slots[2 * index].id)
            XCTAssertEqual(assignments[player]?.secondaryColor.id, slots[2 * index + 1].id)
        }
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
        let viewModel = makePlayingViewModel(.ryb)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        viewModel.pauseTimer()
        viewModel.pressKey(KeyCode.q.rawValue)
        viewModel.pressKey(KeyCode.b.rawValue)
        let originalUnits = viewModel.round!.mix.units.map(\.color.id)
        let originalRatios = viewModel.round!.mix.ratios
        let originalEpoch = viewModel.assignmentEpoch!

        for expected in stride(from: 44, through: 1, by: -1) {
            viewModel.timerTick()
            XCTAssertEqual(viewModel.timerSecondsRemaining, expected)
        }
        viewModel.timerTick()
        XCTAssertEqual(viewModel.timerSecondsRemaining, viewModel.reassignmentDuration)
        XCTAssertEqual(viewModel.round!.mix.units.map(\.color.id), originalUnits)
        XCTAssertEqual(viewModel.round!.mix.ratios, originalRatios)
        XCTAssertEqual(viewModel.assignmentEpoch, originalEpoch + 1)
        assertAssignmentsContainFullPalettePlusOneDuplicate(viewModel)
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
            let viewModel = makePlayingViewModel(.ryb)
            releasedViewModel = viewModel
            XCTAssertNotNil(releasedViewModel)
        }
        XCTAssertNil(releasedViewModel)
    }

    private func makePlayingViewModel(_ model: ColorModel) -> GameViewModel {
        let viewModel = GameViewModel()

        viewModel.confirmSettings()
        return viewModel
    }

    private func assertAssignmentsContainFullPalettePlusOneDuplicate(_ viewModel: GameViewModel,
                                                  file: StaticString = #filePath, line: UInt = #line) {
        guard let round = viewModel.round else {
            XCTFail("Missing round", file: file, line: line)
            return
        }
        assertAssignmentsContainFullPalettePlusOneDuplicate(round.assignments, file: file, line: line)
    }

    private func assertAssignmentsContainFullPalettePlusOneDuplicate(
        _ assignments: [PlayerID: PlayerAssignment],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(assignments.count, PlayerID.allCases.count, file: file, line: line)
        let ids = Set(ColorData.rybPalette.map(\.id))
        var assignedIDs: [UUID] = []
        for player in PlayerID.allCases {
            guard let assignment = assignments[player] else {
                XCTFail("Missing assignment for \(player)", file: file, line: line)
                continue
            }
            XCTAssertEqual(assignment.player, player, file: file, line: line)
            XCTAssertNotEqual(assignment.primaryColor.id, assignment.secondaryColor.id,
                              "Each player's colors must differ", file: file, line: line)
            XCTAssertTrue(ids.contains(assignment.primaryColor.id), file: file, line: line)
            XCTAssertTrue(ids.contains(assignment.secondaryColor.id), file: file, line: line)
            assignedIDs.append(assignment.primaryColor.id)
            assignedIDs.append(assignment.secondaryColor.id)
        }
        XCTAssertEqual(assignedIDs.count, 6, file: file, line: line)
        XCTAssertEqual(Set(assignedIDs), ids, "Every palette color must appear", file: file, line: line)
        let counts = Dictionary(assignedIDs.map { ($0, 1) }, uniquingKeysWith: +)
        XCTAssertEqual(counts.values.sorted(), [1, 1, 1, 1, 2],
                       "Exactly one palette color must be duplicated", file: file, line: line)
    }
}
