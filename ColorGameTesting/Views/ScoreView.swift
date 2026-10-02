import SwiftUI

struct ScoreView: View {
    let viewModel: GameViewModel

    var body: some View {
        if let score = viewModel.score {
            VStack(spacing: 20) {
                Text("Your Score")
                    .font(.largeTitle)
                    .bold()

                Text(score, format: .number.precision(.fractionLength(2)))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Lower scores mean a closer match.")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Button("New Round", action: viewModel.startNewRound)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("No Score", systemImage: "number")
        }
    }
}

#Preview {
    let viewModel = GameViewModel()
    viewModel.phase = .score
    viewModel.score = 12.34
    return ScoreView(viewModel: viewModel)
}
