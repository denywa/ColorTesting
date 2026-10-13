import SwiftUI

struct LocalVotingStatusView: View {
    let coordinator: LocalPlayCoordinator
    var compact = false

    var choices: [String] {
        PlayerID.allCases.enumerated().map { index, player in
            if let vote = coordinator.voting?.votes.first(where: { $0.player == player }) {
                return "Player \(index + 1): chose \(vote.action.rawValue.capitalized) (final)"
            }
            return "Player \(index + 1): waiting for a choice"
        }
    }

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill").accessibilityHidden(true)
                    ForEach(PlayerID.allCases, id: \.self) { player in
                        let number = (PlayerID.allCases.firstIndex(of: player) ?? 0) + 1
                        let vote = coordinator.voting?.votes.first { $0.player == player }
                        Text("\(number): \(vote.map { $0.action.rawValue.capitalized } ?? "–")")
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .font(.caption2.weight(.semibold))
                .padding(4)
            } else {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text("2 matching votes").font(.caption.bold()).foregroundStyle(PlaytestStyle.accent)
                ForEach(Array(PlayerID.allCases.enumerated()), id: \.offset) { index, player in
                    let vote = coordinator.voting?.votes.first { $0.player == player }
                    Text("Player \(index + 1): \(vote.map { $0.action.rawValue.capitalized + " ✓" } ?? "Waiting")")
                        .font(.caption).lineLimit(1)
                        .foregroundStyle(vote == nil ? PlaytestStyle.muted : PlaytestStyle.accent)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Two matching votes immediately run the action.").font(.caption.bold())
                ForEach(choices, id: \.self) { Text($0).font(.caption) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((["Two matching votes immediately run the action."] + choices).joined(separator: " "))
    }
}
