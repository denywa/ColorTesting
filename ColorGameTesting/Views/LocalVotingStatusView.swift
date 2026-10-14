import SwiftUI

struct LocalVotingStatusView: View {
    let coordinator: LocalPlayCoordinator
    var compact = false

    var rule: String {
        coordinator.requiresAllMixVotes ? "All three votes mix the colors. Tap Mix again to cancel your vote." :
        "Two matching votes immediately run the action."
    }

    var statusMessage: String? {
        if coordinator.requiresAllMixVotes {
            return coordinator.colorInputBlockedByVote ? "Waiting for others" : nil
        }
        return "Majority vote · 2 of 3 must agree"
    }

    var choices: [String] {
        PlayerID.allCases.enumerated().map { index, player in
            if let vote = coordinator.voting?.votes.first(where: { $0.player == player }) {
                let state = coordinator.allowsVoteCancellation ? "tap again to cancel" : "final"
                return "Player \(index + 1): chose \(vote.action.rawValue.capitalized) (\(state))"
            }
            return "Player \(index + 1): waiting for a choice"
        }
    }

    var body: some View {
        VStack(spacing: 3) {
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
                Text(coordinator.requiresAllMixVotes ? "3 Mix votes" : "2 matching votes").font(.caption.bold()).foregroundStyle(PlaytestStyle.accent)
                ForEach(Array(PlayerID.allCases.enumerated()), id: \.offset) { index, player in
                    let vote = coordinator.voting?.votes.first { $0.player == player }
                    Text("Player \(index + 1): \(vote.map { $0.action.rawValue.capitalized + " ✓" } ?? "Waiting")")
                        .font(.caption).lineLimit(1)
                        .foregroundStyle(vote == nil ? PlaytestStyle.muted : PlaytestStyle.accent)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(rule).font(.caption.bold())
                ForEach(choices, id: \.self) { Text($0).font(.caption) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
            }
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption2.bold())
                    .foregroundStyle(coordinator.requiresAllMixVotes ? Color(red: 0.65, green: 0.12, blue: 0.38) : PlaytestStyle.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.95), in: Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(([rule] + choices + (statusMessage.map { [$0] } ?? [])).joined(separator: " "))
    }
}
