import Foundation

enum RunTimerMode: String, Codable, CaseIterable {
    case day, client
    var title: String { self == .day ? "Day Timer" : "Client Timer" }
}

struct DayTemplate: Codable, Equatable {
    var levels: [RequestDifficulty]
    var target: Int { levels.count }

    mutating func setTarget(_ count: Int) {
        guard (1...100).contains(count) else { return }
        if count > levels.count {
            levels += Array(repeating: levels.last ?? .level1, count: count - levels.count)
        } else { levels = Array(levels.prefix(count)) }
    }
}

struct EndlessRunConfiguration: Codable, Equatable {
    var templates: [DayTemplate] = [
        .init(levels: [.level1, .level1, .level1]),
        .init(levels: [.level1, .level1, .level2]),
        .init(levels: [.level1, .level2, .level2]),
        .init(levels: [.level1, .level2, .level3]),
        .init(levels: [.level2, .level2, .level3]),
        .init(levels: [.level2, .level3, .level3]),
        .init(levels: [.level3, .level3, .level3])
    ]
    var timerMode: RunTimerMode = .day
    var dayDuration = 600
    var clientDuration = 180
    var passingScore = 70.0
    var mistakeLimit: Int? = 3

    var isValid: Bool {
        templates.count == 7 && templates.allSatisfy { (1...100).contains($0.target) } &&
        (1...86_400).contains(dayDuration) && (1...86_400).contains(clientDuration) &&
        passingScore.isFinite && (0...100).contains(passingScore) &&
        (mistakeLimit.map { (1...100).contains($0) } ?? true)
    }
    var budget: Int { timerMode == .day ? dayDuration : clientDuration }
    static func templateIndex(for day: Int) -> Int {
        day <= 7 ? max(0, day - 1) : 4 + (day - 8) % 3
    }
}

enum RunStatus: String, Codable { case active, dayComplete, gameOver }
enum RunAttemptOutcome: String, Codable { case passed, failed, timedOut }
enum RunFailure: String, Codable {
    case mistakes, dayTimeExpired
    var message: String {
        self == .mistakes ? "The Day's mistake limit was reached." : "Time ran out before the Day's target was completed."
    }
}

struct EndlessRunState: Codable, Equatable {
    let id: UUID
    let configuration: EndlessRunConfiguration
    var day = 1
    var completed = 0
    var mistakes = 0
    var remainingSeconds: Int
    var status: RunStatus = .active
    var outcome: RunAttemptOutcome?
    var failure: RunFailure?

    init(configuration: EndlessRunConfiguration) {
        id = UUID()
        self.configuration = configuration
        remainingSeconds = configuration.budget
    }
    var templateIndex: Int { EndlessRunConfiguration.templateIndex(for: day) }
    var template: DayTemplate { configuration.templates[templateIndex] }
    var currentLevel: RequestDifficulty {
        let slot = outcome == .passed ? max(0, completed - 1) : completed
        return template.levels[min(slot, template.target - 1)]
    }
    var hasGrade: Bool { outcome == .passed || outcome == .failed }

    @discardableResult mutating func grade(_ score: Double) -> Bool {
        guard status == .active, !hasGrade, score.isFinite, (0...100).contains(score) else { return false }
        if score >= configuration.passingScore {
            outcome = .passed
            completed += 1
            if completed == template.target { status = .dayComplete }
        } else {
            outcome = .failed
            addMistake()
        }
        return true
    }

    mutating func clientTimedOut() {
        guard status == .active, !hasGrade else { return }
        outcome = .timedOut
        addMistake()
    }

    mutating func expireDay() {
        guard status == .active else { return }
        status = .gameOver
        failure = .dayTimeExpired
        remainingSeconds = 0
    }

    @discardableResult mutating func advanceDay() -> Bool {
        guard status == .dayComplete, day < Int.max else { return false }
        day += 1
        completed = 0
        mistakes = 0
        outcome = nil
        failure = nil
        status = .active
        remainingSeconds = configuration.budget
        return true
    }

    private mutating func addMistake() {
        // Keep the counter representable even in an unlimited testing session.
        if mistakes < Int.max { mistakes += 1 }
        if let limit = configuration.mistakeLimit, mistakes >= limit {
            status = .gameOver
            failure = .mistakes
        }
    }

    var isValid: Bool {
        guard configuration.isValid, day > 0, completed >= 0, completed <= template.target,
              mistakes >= 0, (0...configuration.budget).contains(remainingSeconds) else { return false }
        if let limit = configuration.mistakeLimit {
            guard mistakes <= limit, (mistakes == limit) == (failure == .mistakes) else { return false }
        } else if failure == .mistakes { return false }
        if (outcome == .failed || outcome == .timedOut) && mistakes == 0 { return false }
        if outcome == .passed && completed == 0 { return false }
        if failure == .mistakes && outcome != .failed && outcome != .timedOut { return false }
        switch status {
        case .active: return completed < template.target && failure == nil
        case .dayComplete: return completed == template.target && outcome == .passed && failure == nil
        case .gameOver:
            return failure != nil && completed < template.target &&
                (failure != .dayTimeExpired || (configuration.timerMode == .day && remainingSeconds == 0))
        }
    }
}

// The host owns this clock; clients only display the published remaining seconds.
struct RunBudgetClock {
    private(set) var deadline: Date?
    private var frozenRemaining: TimeInterval = 0
    var isRunning: Bool { deadline != nil }
    func remaining(at now: Date) -> TimeInterval {
        min(frozenRemaining, max(0, deadline?.timeIntervalSince(now) ?? frozenRemaining))
    }
    mutating func start(seconds: Int, at now: Date) {
        frozenRemaining = Double(seconds)
        deadline = now.addingTimeInterval(frozenRemaining)
    }
    mutating func pause(at now: Date) {
        frozenRemaining = remaining(at: now)
        deadline = nil
    }
    mutating func resume(at now: Date) { deadline = now.addingTimeInterval(frozenRemaining) }
}
