import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor
final class EndlessRunTests: XCTestCase {
    private final class Clock {
        var date = Date(timeIntervalSince1970: 10_000)
        func advance(_ seconds: Double) { date += seconds }
    }
    private func model(_ clock: Clock, mode: RunTimerMode = .day, passing: Double = 70) -> GameViewModel {
        let vm = GameViewModel(requestDefaults: UserDefaults(suiteName: "EndlessRunTests.\(UUID())")!, now: { clock.date })
        var config = EndlessRunConfiguration()
        config.timerMode = mode
        config.dayDuration = 10
        config.clientDuration = 5
        config.passingScore = passing
        vm.runConfiguration = config
        return vm
    }

    func testRequestPoolsExhaustBeforeRepeatingAcrossDaysIncludingCustomRequests() throws {
        for level in RequestDifficulty.allCases {
            let vm = model(Clock(), passing: 0)
            defer { vm.returnToSettings() }
            XCTAssertTrue(vm.addCustomRequest(text: "Queue test", hex: "123456", difficulty: level))
            var config = vm.runConfiguration
            config.templates = (0..<7).map { _ in DayTemplate(levels: [level]) }
            vm.runConfiguration = config
            vm.selectMixMode(.auto)
            vm.startEndlessRun()
            let pool = Set(vm.availableRequests.filter { $0.difficulty == level }.map(\.id))
            var previous: UUID?
            for _ in 0..<3 {
                var seen = Set<UUID>()
                for _ in pool {
                    let request = try XCTUnwrap(vm.round?.request)
                    XCTAssertEqual(request.difficulty, level)
                    XCTAssertNotEqual(request.id, previous)
                    XCTAssertTrue(seen.insert(request.id).inserted)
                    previous = request.id
                    vm.addColor(player: .player1, slot: .primary)
                    vm.selectApply()
                    vm.continueRun()
                }
                XCTAssertEqual(seen, pool)
            }
        }
    }

    func testLivesPresentationTracksRemainingAndUnlimitedLives() {
        var run = EndlessRunState(configuration: .init())
        XCTAssertEqual(RunLivesView(run: run).remaining, 3)
        run.mistakes = 1
        XCTAssertEqual(RunLivesView(run: run).remaining, 2)
        run.mistakes = 3
        XCTAssertEqual(RunLivesView(run: run).remaining, 0)
        var unlimited = EndlessRunConfiguration()
        unlimited.mistakeLimit = nil
        XCTAssertNil(RunLivesView(run: EndlessRunState(configuration: unlimited)).remaining)
    }

    func testDefaultScheduleAndEditedTargetsRepeatAfterSeven() {
        var config = EndlessRunConfiguration()
        XCTAssertEqual(config.templates.map { $0.levels.map(\.rawValue) },
                       [[1,1,1], [1,1,2], [1,2,2], [1,2,3], [2,2,3], [2,3,3], [3,3,3]])
        XCTAssertEqual((1...13).map(EndlessRunConfiguration.templateIndex), [0,1,2,3,4,5,6,4,5,6,4,5,6])
        XCTAssertEqual(config.dayDuration, 600)
        XCTAssertEqual(config.clientDuration, 180)
        XCTAssertEqual(config.passingScore, 70)
        XCTAssertEqual(config.mistakeLimit, 3)
        config.templates[4].setTarget(5)
        config.templates[4].levels[3] = .level1
        var run = EndlessRunState(configuration: config)
        run.day = 8
        XCTAssertEqual(run.template.target, 5)
        XCTAssertEqual(run.template.levels, [.level2, .level2, .level3, .level1, .level3])
        run.day = 11
        XCTAssertEqual(run.template, config.templates[4])
    }

    func testThresholdAndDailyMistakesAreCountedOnceAndResetOnNextDay() {
        var run = EndlessRunState(configuration: .init())
        XCTAssertTrue(run.grade(69.99))
        XCTAssertFalse(run.grade(0), "One graded attempt cannot count twice")
        XCTAssertEqual(run.mistakes, 1)
        XCTAssertEqual(run.completed, 0)
        run.outcome = nil
        for _ in 0..<3 {
            XCTAssertTrue(run.grade(70))
            if run.status == .active { run.outcome = nil }
        }
        XCTAssertEqual(run.status, .dayComplete)
        run.expireDay()
        XCTAssertEqual(run.status, .dayComplete, "A passed Day cannot expire")
        XCTAssertTrue(run.advanceDay())
        XCTAssertEqual(run.day, 2)
        XCTAssertEqual(run.completed, 0)
        XCTAssertEqual(run.mistakes, 0)
        XCTAssertTrue(run.isValid)
        for i in 1...3 {
            run.outcome = nil
            XCTAssertTrue(run.grade(0))
            XCTAssertEqual(run.mistakes, i)
        }
        XCTAssertEqual(run.status, .gameOver)
        XCTAssertEqual(run.failure, .mistakes)
        XCTAssertFalse(run.grade(100))
    }

    func testUnlimitedMistakesAndConfigurationValidation() {
        var config = EndlessRunConfiguration()
        config.mistakeLimit = nil
        var run = EndlessRunState(configuration: config)
        for _ in 0..<12 { run.outcome = nil; XCTAssertTrue(run.grade(0)) }
        XCTAssertEqual(run.mistakes, 12)
        XCTAssertEqual(run.status, .active)
        XCTAssertTrue(run.isValid)
        config.templates.removeLast()
        XCTAssertFalse(config.isValid)
        config = .init(); config.templates[0].levels = []
        XCTAssertFalse(config.isValid)
        config = .init(); config.passingScore = .nan
        XCTAssertFalse(config.isValid)
        config = .init(); config.mistakeLimit = 0
        XCTAssertFalse(config.isValid)
    }

    func testClientTimeoutStartsNewTargetOnceThenThirdTimeoutEndsRun() {
        let clock = Clock()
        let game = model(clock, mode: .client)
        defer { game.returnToSettings() }
        game.startEndlessRun()
        let target = game.round?.request.id
        let oldRound = game.roundID
        game.addColor(player: .player1, slot: .primary)
        game.pressMixButton()
        XCTAssertEqual(game.phase, .result)
        clock.advance(5)
        game.refreshRunBudget()
        XCTAssertEqual(game.phase, .playing)
        XCTAssertEqual(game.run?.mistakes, 1)
        XCTAssertEqual(game.run?.remainingSeconds, 5)
        XCTAssertNotEqual(game.roundID, oldRound)
        XCTAssertNotEqual(game.round?.request.id, target)
        XCTAssertTrue(game.round?.mix.units.isEmpty == true)
        XCTAssertEqual(game.run?.completed, 0)
        game.refreshRunBudget()
        XCTAssertEqual(game.run?.mistakes, 1)
        for _ in 0..<2 { clock.advance(5); game.refreshRunBudget() }
        XCTAssertEqual(game.phase, .gameOver)
        XCTAssertEqual(game.run?.mistakes, 3)
        XCTAssertEqual(game.run?.failure, .mistakes)
        XCTAssertNil(game.score, "Timeout must not fabricate a match score")
        game.restartRun()
        XCTAssertEqual(game.run?.day, 1)
        XCTAssertEqual(game.run?.mistakes, 0)
        XCTAssertEqual(game.run?.remainingSeconds, 5)
        XCTAssertEqual(game.runConfiguration.timerMode, .client)
    }

    func testDayBudgetRunsThroughManualResultAndUnfinishedScoreFeedback() {
        let clock = Clock()
        let vm = model(clock, passing: 0)
        defer { vm.returnToSettings() }
        vm.startEndlessRun()
        vm.addColor(player: .player1, slot: .primary)
        vm.pressMixButton()
        clock.advance(3)
        vm.refreshRunBudget()
        XCTAssertEqual(vm.phase, .result)
        XCTAssertEqual(vm.run?.remainingSeconds, 7)
        vm.selectFinish()
        XCTAssertEqual(vm.phase, .score)
        XCTAssertEqual(vm.run?.completed, 1)
        clock.advance(7)
        vm.refreshRunBudget()
        XCTAssertEqual(vm.phase, .gameOver)
        XCTAssertEqual(vm.run?.failure, .dayTimeExpired)
    }

    func testFailedClientScoreStopsBudgetUntilNextClientAndRedoDoesNotReplenishIt() {
        let clock = Clock(), vm = model(clock, mode: .client, passing: 100)
        defer { vm.returnToSettings() }
        vm.selectMixMode(.auto)
        vm.startEndlessRun()
        let target = vm.round?.request.id
        vm.addColor(player: .player1, slot: .primary)
        vm.selectApply()
        XCTAssertEqual(vm.run?.outcome, .failed)
        XCTAssertEqual(vm.run?.mistakes, 1)
        clock.advance(100)
        vm.refreshRunBudget()
        XCTAssertEqual(vm.phase, .score)
        XCTAssertEqual(vm.run?.mistakes, 1)
        vm.continueRun()
        XCTAssertNotEqual(vm.round?.request.id, target)
        XCTAssertEqual(vm.run?.completed, 0)
        XCTAssertEqual(ScoreView(viewModel: vm).nextTitle, "Next Client")
        XCTAssertEqual(vm.run?.remainingSeconds, 5)
        vm.addColor(player: .player1, slot: .primary)
        clock.advance(3)
        vm.selectRedo()
        XCTAssertEqual(vm.run?.remainingSeconds, 2)
        XCTAssertEqual(vm.run?.mistakes, 1)
        clock.advance(2)
        vm.refreshRunBudget()
        XCTAssertEqual(vm.run?.mistakes, 2)
    }

    func testExactDeadlineRejectsLateGradingAndPausePreservesFractionalBudget() {
        let clock = Clock(), vm = model(clock, passing: 0)
        defer { vm.returnToSettings() }
        vm.selectMixMode(.auto)
        vm.startEndlessRun()
        vm.addColor(player: .player1, slot: .primary)
        clock.advance(2.5)
        vm.pauseSessionClocks()
        let remaining = vm.timerSecondsRemaining
        vm.timerTick()
        XCTAssertEqual(vm.timerSecondsRemaining, remaining)
        clock.advance(100)
        vm.refreshRunBudget()
        XCTAssertEqual(vm.run?.remainingSeconds, 8)
        vm.resumeSessionClocks()
        clock.advance(7.5)
        vm.selectApply()
        XCTAssertEqual(vm.phase, .gameOver)
        XCTAssertNil(vm.score)
        XCTAssertEqual(vm.run?.completed, 0)
    }

    func testContinueChangesClientsAndDaysWithoutSettingsAndConfigurationIsFrozen() {
        let clock = Clock(), vm = model(clock, passing: 0)
        defer { vm.returnToSettings() }
        var config = vm.runConfiguration
        config.templates[0].levels = [.level1]
        config.templates[1].levels = [.level3, .level2]
        vm.runConfiguration = config
        vm.selectMixMode(.auto)
        vm.startEndlessRun()
        var ignored = config; ignored.passingScore = 100
        vm.runConfiguration = ignored
        XCTAssertEqual(vm.runConfiguration, config)
        vm.addColor(player: .player1, slot: .primary)
        vm.selectApply()
        XCTAssertEqual(vm.run?.status, .dayComplete)
        clock.advance(100)
        vm.refreshRunBudget()
        XCTAssertEqual(vm.run?.status, .dayComplete)
        vm.continueRun()
        XCTAssertEqual(vm.phase, .playing)
        XCTAssertEqual(vm.run?.day, 2)
        XCTAssertEqual(vm.round?.request.difficulty, .level3)
        vm.addColor(player: .player1, slot: .primary)
        vm.selectApply()
        vm.continueRun()
        XCTAssertEqual(vm.run?.day, 2)
        XCTAssertEqual(vm.run?.completed, 1)
        XCTAssertEqual(vm.round?.request.difficulty, .level2)
        vm.returnToSettings()
        XCTAssertNil(vm.run)
        XCTAssertNil(vm.roundID)
        XCTAssertEqual(vm.phase, .settings)
        XCTAssertEqual(vm.runConfiguration, config)
    }
}
