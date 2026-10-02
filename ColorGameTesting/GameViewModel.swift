import AppKit
import Observation

@MainActor
@Observable
final class GameViewModel {
    var phase: GamePhase = .settings
    private(set) var gameState = GameState()
    var selectedModel: ColorModel? {
        get { gameState.selectedModel }
        set { gameState.selectedModel = newValue }
    }
    var round: Round? {
        get { gameState.round }
        set { gameState.round = newValue }
    }
    var mixResult: SIMD3<Double>? {
        get { gameState.mixResult }
        set { gameState.mixResult = newValue }
    }
    var score: Double? {
        get { gameState.score }
        set { gameState.score = newValue }
    }
    var timerSecondsRemaining = 45

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var keyMonitor: Any?

    var canConfirm: Bool { selectedModel != nil }

    func selectModel(_ model: ColorModel) {
        guard phase == .settings else { return }
        selectedModel = model
    }

    func confirmSettings() {
        guard phase == .settings, let selectedModel else { return }
        assert(!ColorData.requestPool.isEmpty, "The color request pool must not be empty")
        let request = ColorData.requestPool.randomElement() ?? ColorRequest(
            id: UUID(), text: "Mix a warm sunset", targetSRGB: SIMD3(0.96, 0.51, 0.32)
        )
        gameState = GameState(
            selectedModel: selectedModel,
            round: Round(
                request: request,
                colorModel: selectedModel,
                assignments: randomAssignments(for: selectedModel),
                mix: Mix()
            ),
            mixResult: nil,
            score: nil
        )
        timerSecondsRemaining = 45
        phase = .playing
        startTimer()
        installKeyMonitor()
    }

    func pressKey(_ keyCode: UInt16) {
        guard phase == .playing,
              let action = KeyRouter.action(for: keyCode),
              round?.mix.isLocked == false else { return }

        switch action {
        case let .addColor(player, colorSlot):
            guard let assignment = round?.assignments[player] else { return }
            let color = colorSlot == .primary ? assignment.primaryColor : assignment.secondaryColor
            round?.mix.units.append(ColorUnit(color: color))
        }
    }

    func timerTick() {
        guard phase == .playing, round?.mix.isLocked == false else { return }
        if timerSecondsRemaining > 0 {
            timerSecondsRemaining -= 1
        }
        if timerSecondsRemaining == 0 {
            triggerReassignment()
        }
    }

    func triggerReassignment() {
        guard phase == .playing, let model = round?.colorModel,
              round?.mix.isLocked == false else { return }
        round?.assignments = randomAssignments(for: model)
        timerSecondsRemaining = 45
    }

    func startTimer() {
        guard timer == nil, phase == .playing,
              round?.mix.isLocked == false else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.timerTick() }
        }
    }

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
    }

    func resumeTimer() {
        startTimer()
    }

    func installKeyMonitor() {
        guard keyMonitor == nil, phase == .playing else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.pressKey(event.keyCode)
            return event
        }
    }

    func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    func pressMixButton() {
        guard phase == .playing, let round,
              !round.mix.units.isEmpty, !round.mix.isLocked else { return }
        self.round?.mix.isLocked = true
        pauseTimer()
        removeKeyMonitor()
        mixResult = ColorMixer.blend(round.mix.units, model: round.colorModel)
        phase = .result
    }

    func selectRedo() {
        guard phase == .result, round?.mix.isLocked == true else { return }
        round?.mix.units.removeAll()
        round?.mix.isLocked = false
        mixResult = nil
        phase = .playing
        resumeTimer()
        installKeyMonitor()
    }

    func selectFinish() {
        guard phase == .result, let mixResult,
              let target = round?.request.targetSRGB else { return }
        let resultLab = ColorConverter.sRGBToLab(mixResult)
        let targetLab = ColorConverter.sRGBToLab(target)
        score = ScoreCalculator.deltaE2000(resultLab, targetLab)
        pauseTimer()
        phase = .score
    }

    func startNewRound() {
        guard phase == .score else { return }
        pauseTimer()
        removeKeyMonitor()
        gameState = GameState()
        timerSecondsRemaining = 45
        phase = .settings
    }

    private func randomAssignments(for model: ColorModel) -> [PlayerID: PlayerAssignment] {
        let palette = ColorData.colors(for: model)
        assert(!palette.isEmpty, "The color palette must not be empty")
        var assignments: [PlayerID: PlayerAssignment] = [:]
        for player in PlayerID.allCases {
            assignments[player] = PlayerAssignment(
                player: player,
                primaryColor: palette.randomElement()!,
                secondaryColor: palette.randomElement()!
            )
        }
        return assignments
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        timer?.invalidate()
    }
}
