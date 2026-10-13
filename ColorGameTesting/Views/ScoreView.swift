import SwiftUI

struct ScoreView: View {
    let viewModel: GameViewModel
    let coordinator: LocalPlayCoordinator?
    var exitAction: (() -> Void)?

    init(viewModel: GameViewModel, coordinator: LocalPlayCoordinator? = nil, exitAction: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.exitAction = exitAction
    }

    var showsNewRound: Bool {
        coordinator == nil || coordinator?.role == .host
    }
    var newRoundDisabled: Bool { coordinator?.paused == true }
    var nextTitle: String {
        guard let run = viewModel.run else { return "New Round" }
        if run.status == .dayComplete { return run.day < Int.max ? "Continue to Day \(run.day + 1)" : "Continue" }
        return "Next Client"
    }
    var pauseStatus: String? {
        guard coordinator?.paused == true else { return nil }
        if let missing = coordinator?.seatStatus.first(where: { $0.status == .disconnected }) {
            let number = (PlayerID.allCases.firstIndex(of: missing.player) ?? 0) + 1
            return "Paused — waiting for Player \(number) to reconnect"
        }
        return "Paused — waiting for connection"
    }

    func newRound() {
        if let coordinator {
            coordinator.perform(viewModel.run == nil ? .newRound : .continueRun)
        } else {
            if viewModel.run == nil { viewModel.startNewRound() } else { viewModel.continueRun() }
        }
    }

    var body: some View {
        if let score = viewModel.score {
            GeometryReader { geometry in layoutContent(score: score, size: geometry.size) }
        } else {
            ContentUnavailableView("No Score", systemImage: "number")
        }
    }

    func layoutContent(score: Double, size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RunHeaderView(run: viewModel.run, exitTitle: coordinator == nil || coordinator?.role == .host ? "Lobby" : "Leave",
                          exitAccessibilityLabel: coordinator == nil ? "Back to Settings" : coordinator?.role == .host ? "Back to Settings and Lobby" : "Leave Session", exitAction: exitAction)
            HStack(spacing: 12) {
                scoreCard(score, compact: true).frame(width: min(180, size.width * 0.25))
                comparison(height: max(44, min(PlaytestStyle.maximumComparisonHeight, size.height - 185)), compact: true)
            }
            .frame(maxHeight: .infinity)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shortFeedback).font(.caption).foregroundStyle(PlaytestStyle.muted)
                        .lineLimit(2).accessibilityLabel(feedback)
                    if let pauseStatus {
                        Text(pauseStatus).font(.caption).foregroundStyle(PlaytestStyle.accent)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if showsNewRound {
                    Button(nextTitle, action: newRound)
                        .buttonStyle(PlaytestButtonStyle()).disabled(newRoundDisabled)
                } else {
                    Text("Waiting for the host").font(.caption)
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shortFeedback: String {
        guard let run = viewModel.run else { return "Higher scores mean a closer match." }
        if run.status == .dayComplete { return "Day passed!" }
        return run.outcome == .failed ? (run.configuration.mistakeLimit == nil ? "Client missed" : "Client missed · 1 life lost") : "Client completed!"
    }

    private var feedback: String {
        guard let run = viewModel.run else { return "One mix. One score. Made together." }
        if run.status == .dayComplete { return "Day passed! Your next Day is ready." }
        if run.outcome == .failed { return run.configuration.mistakeLimit == nil ? "Client missed. Continue to a new client." : "Client missed. One life lost; continue to a new client." }
        return "Client completed! Continue to the next request."
    }

    private var passed: Bool? {
        guard let run = viewModel.run, run.hasGrade else { return nil }
        return run.outcome == .passed
    }

    private func scoreCard(_ score: Double, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let passed {
                Label(passed ? "PASS" : "MISS", systemImage: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(passed ? PlaytestStyle.success : PlaytestStyle.failure)
                    .accessibilityAddTraits(.isHeader)
                if !passed {
                    Text(viewModel.run?.configuration.mistakeLimit == nil ? "NO LIFE LIMIT" : "−1 LIFE").font(.caption.bold()).foregroundStyle(PlaytestStyle.failure)
                }
            } else {
                Text("MATCH SCORE").font(.caption.bold()).tracking(2)
            }
            Text(score / 100, format: .percent.precision(.fractionLength(2)))
                .font(passed == nil ? .largeTitle.bold() : .caption.monospacedDigit())
                .foregroundStyle(PlaytestStyle.muted)
                .minimumScaleFactor(0.6).lineLimit(1)
                .accessibilityLabel("Color match score")
                .accessibilityValue("\(score.formatted(.number.precision(.fractionLength(2)))) percent")
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 44 : 160, alignment: .leading)
        .padding(12)
        .background((passed.map { $0 ? PlaytestStyle.success : PlaytestStyle.failure } ?? .white).opacity(passed == nil ? 1 : 0.12), in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder private func comparison(height: CGFloat = 140, compact: Bool = false) -> some View {
        if let round = viewModel.round, let result = viewModel.mixResult {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: compact ? 6 : 10) {
                    ColorSwatch(color: result, name: "Your Mix", height: height)
                    Text("Your Mix").font(compact ? .caption.bold() : .headline)
                }
                VStack(alignment: .leading, spacing: compact ? 6 : 10) {
                    ColorSwatch(color: round.request.targetSRGB, name: "Target color", height: height)
                    Text("Target").font(compact ? .caption.bold() : .headline)
                }
            }
            .frame(minWidth: compact ? 160 : 270, maxWidth: .infinity)
            .playtestCard(inset: compact ? 10 : nil)
        }
    }

}

#Preview {
    let viewModel = GameViewModel()
    viewModel.phase = .score
    viewModel.score = 87.76
    return ScoreView(viewModel: viewModel)
}
