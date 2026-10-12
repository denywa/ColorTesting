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
            // Auto scoring arrives in task 6.2; exercise the existing score reset seam.
            viewModel.phase = .score
            viewModel.mixResult = SIMD3(0.1, 0.2, 0.3)
            viewModel.score = 50
            viewModel.startNewRound()
            XCTAssertEqual(viewModel.phase, .settings)
            XCTAssertEqual(viewModel.selectedModel, .ryb)
            XCTAssertEqual(viewModel.selectedMixMode, .manual)
            XCTAssertNil(viewModel.round)
            XCTAssertNil(viewModel.roundID)
            XCTAssertNil(viewModel.assignmentEpoch)
            XCTAssertNil(viewModel.selectedRequestID)
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
        for model in ColorModel.allCases {
            let viewModel = makePlayingViewModel(model)
            defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
            assertAssignmentsContainFullPalettePlusOneDuplicate(viewModel)
            for _ in 0..<100 {
                viewModel.triggerReassignment()
                assertAssignmentsContainFullPalettePlusOneDuplicate(viewModel)
            }
        }
    }

    func testDuplicateCanLandWithinOnePlayerOrAcrossTwoPlayers() {
        let viewModel = makePlayingViewModel(.ryb)
        defer { viewModel.pauseTimer(); viewModel.removeKeyMonitor() }
        var sawWithinPlayer = false
        var sawAcrossPlayers = false
        var duplicatedColors = Set<UUID>()
        for _ in 0..<200 {
            assertAssignmentsContainFullPalettePlusOneDuplicate(viewModel)
            let assignments = viewModel.round!.assignments
            let within = assignments.values.contains { $0.primaryColor.id == $0.secondaryColor.id }
            let ids = assignments.values.flatMap { [$0.primaryColor.id, $0.secondaryColor.id] }
            let counts = Dictionary(ids.map { ($0, 1) }, uniquingKeysWith: +)
            if let duplicate = counts.first(where: { $0.value == 2 })?.key {
                duplicatedColors.insert(duplicate)
            }
            sawWithinPlayer = sawWithinPlayer || within
            sawAcrossPlayers = sawAcrossPlayers || !within
            viewModel.triggerReassignment()
        }
        XCTAssertTrue(sawWithinPlayer, "The duplicate must be able to occupy one player's pair")
        XCTAssertTrue(sawAcrossPlayers, "The duplicate must be able to occupy two players' slots")
        XCTAssertEqual(duplicatedColors, Set(ColorData.rybPalette.map(\.id)),
                       "Each palette color must be eligible as the extra color")
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

        for expected in stride(from: 44, through: 1, by: -1) {
            viewModel.timerTick()
            XCTAssertEqual(viewModel.timerSecondsRemaining, expected)
        }
        viewModel.timerTick()
        XCTAssertEqual(viewModel.timerSecondsRemaining, viewModel.reassignmentDuration)
        XCTAssertEqual(viewModel.round!.mix.units.map(\.color.id), originalUnits)
        XCTAssertEqual(viewModel.round!.mix.ratios, originalRatios)
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
        let ids = Set(ColorData.colors(for: round.colorModel).map(\.id))
        var assignedIDs: [UUID] = []
        for player in PlayerID.allCases {
            guard let assignment = round.assignments[player] else {
                XCTFail("Missing assignment for \(player)", file: file, line: line)
                continue
            }
            XCTAssertEqual(assignment.player, player, file: file, line: line)
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
