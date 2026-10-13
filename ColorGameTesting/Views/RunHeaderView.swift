import SwiftUI

struct RunHeaderView: View {
    let run: EndlessRunState?
    var exitTitle = "Lobby"
    var exitAccessibilityLabel = "Back to Settings and Lobby"
    var exitAction: (() -> Void)?

    var body: some View {
        ZStack {
            if let run {
                Label(RunStatusView.time(run.remainingSeconds), systemImage: run.configuration.timerMode == .client ? "person.fill" : "timer")
                    .font(.headline.monospacedDigit())
                    .accessibilityLabel("\(run.configuration.timerMode.title), \(run.remainingSeconds) seconds remaining")
            }
            HStack(spacing: 8) {
                if let run { RunLivesView(run: run) }
                Spacer(minLength: 8)
                if let run {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day \(run.day)")
                        Text("Clients \(run.completed)/\(run.template.target)")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                }
                if let exitAction {
                    Button(exitTitle, action: exitAction)
                        .buttonStyle(PlaytestButtonStyle(primary: false))
                        .accessibilityLabel(exitAccessibilityLabel)
                }
            }
        }
        .frame(minHeight: 44)
    }
}
