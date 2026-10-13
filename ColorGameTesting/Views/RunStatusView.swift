import SwiftUI

struct RunStatusView: View {
    let run: EndlessRunState

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { labels }
            VStack(alignment: .leading, spacing: 4) { labels }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PlaytestStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var labels: some View {
        Text("Day \(run.day) · Stage \(run.templateIndex + 1)")
        Text("Clients \(run.completed)/\(run.template.target)")
        RunLivesView(run: run, compact: true)
        Label(Self.time(run.remainingSeconds), systemImage: run.configuration.timerMode == .client ? "person.fill" : "timer")
            .monospacedDigit()
            .accessibilityLabel("\(run.configuration.timerMode.title), \(run.remainingSeconds) seconds remaining")
    }

    static func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}
