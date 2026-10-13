import SwiftUI

struct RunLivesView: View {
    let run: EndlessRunState
    var compact = false

    var remaining: Int? { run.configuration.mistakeLimit.map { max(0, $0 - run.mistakes) } }

    var body: some View {
        HStack(spacing: 5) {
            if let limit = run.configuration.mistakeLimit, limit <= 5 {
                ForEach(0..<limit, id: \.self) { index in
                    Image(systemName: index < (remaining ?? 0) ? "heart.fill" : "heart")
                        .foregroundStyle(index < (remaining ?? 0) ? Color.red : PlaytestStyle.muted)
                }
            } else {
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text(remaining.map(String.init) ?? "∞").monospacedDigit()
            }
        }
        .font(compact ? .caption : .title3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(remaining.map { "\($0) lives remaining" } ?? "Unlimited lives")
    }
}
