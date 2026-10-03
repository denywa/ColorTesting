import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

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
    /// Nil means the next round chooses a request at random.
    var selectedRequestID: UUID?
    private(set) var customRequests: [ColorRequest]
    var reassignmentDuration = 45
    var showTargetColor = false
    var timerSecondsRemaining = 45

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let customRequestStore: CustomRequestStore
    #if os(macOS)
    @ObservationIgnored private var keyMonitor: Any?
    #endif

    init(requestDefaults: UserDefaults = .standard) {
        let store = CustomRequestStore(defaults: requestDefaults)
        customRequestStore = store
        customRequests = store.load()
    }

    var availableRequests: [ColorRequest] { ColorData.requestPool + customRequests }
    var canConfirm: Bool { selectedModel != nil }

    @discardableResult
    func addCustomRequest(text: String, hex: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .settings, !trimmedText.isEmpty,
              let color = ColorHex.sRGB(hex) else { return false }
        let request = ColorRequest(id: UUID(), text: trimmedText, targetSRGB: color)
        let updatedRequests = customRequests + [request]
        guard customRequestStore.save(updatedRequests) else { return false }
        customRequests = updatedRequests
        selectedRequestID = request.id
        return true
    }

    func selectModel(_ model: ColorModel) {
        guard phase == .settings else { return }
        selectedModel = model
    }

    func confirmSettings() {
        guard phase == .settings, let selectedModel else { return }
        assert(!ColorData.requestPool.isEmpty, "The color request pool must not be empty")
        let request = availableRequests.first { $0.id == selectedRequestID }
            ?? availableRequests.randomElement()
            ?? ColorRequest(id: UUID(), text: "Mix a warm sunset",
                            targetSRGB: SIMD3(0.96, 0.51, 0.32))
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
        timerSecondsRemaining = reassignmentDuration
        phase = .playing
        startTimer()
        installKeyMonitor()
    }

    func pressKey(_ keyCode: UInt16) {
        guard let action = KeyRouter.action(for: keyCode) else { return }

        switch action {
        case let .addColor(player, colorSlot):
            addColor(player: player, slot: colorSlot)
        }
    }

    func addColor(player: PlayerID, slot: ColorSlot) {
        guard phase == .playing, round?.mix.isLocked == false,
              let assignment = round?.assignments[player] else { return }
        let color = slot == .primary ? assignment.primaryColor : assignment.secondaryColor
        round?.mix.units.append(ColorUnit(color: color))
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
        timerSecondsRemaining = reassignmentDuration
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
        #if os(macOS)
        guard keyMonitor == nil, phase == .playing else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.pressKey(event.keyCode)
            return event
        }
        #endif
    }

    func removeKeyMonitor() {
        #if os(macOS)
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        #endif
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
        score = ScoreCalculator.matchPercentage(resultLab, targetLab)
        pauseTimer()
        phase = .score
    }

    func startNewRound() {
        guard phase == .score else { return }
        pauseTimer()
        removeKeyMonitor()
        gameState = GameState()
        selectedRequestID = nil
        timerSecondsRemaining = reassignmentDuration
        phase = .settings
    }

    private func randomAssignments(for model: ColorModel) -> [PlayerID: PlayerAssignment] {
        let palette = ColorData.colors(for: model)
        precondition(palette.count == 5 && Set(palette.map(\.id)).count == 5,
                     "Each color model must have five distinct palette colors")
        var slots = palette + [palette.randomElement()!]
        slots.shuffle()
        var assignments: [PlayerID: PlayerAssignment] = [:]
        for (index, player) in PlayerID.allCases.enumerated() {
            assignments[player] = PlayerAssignment(
                player: player,
                primaryColor: slots[2 * index],
                secondaryColor: slots[2 * index + 1]
            )
        }
        return assignments
    }

    deinit {
        #if os(macOS)
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        #endif
        timer?.invalidate()
    }
}
