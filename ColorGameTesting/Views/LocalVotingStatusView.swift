import SwiftUI

struct LocalVotingStatusView: View {
    let coordinator: LocalPlayCoordinator

    var choices: [String] {
        PlayerID.allCases.enumerated().map { index, player in
            if let vote = coordinator.voting?.votes.first(where: { $0.player == player }) {
                return "Player \(index + 1): chose \(vote.action.rawValue.capitalized) (final)"
            }
            return "Player \(index + 1): waiting for a choice"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Two matching votes immediately run the action.")
                .font(.headline)
            ForEach(choices, id: \.self) { choice in
                Text(choice)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel((["Two matching votes immediately run the action."] + choices).joined(separator: " "))
    }
}
