import SwiftUI

struct ScoreView: View {
    let viewModel: GameViewModel

    var body: some View {
        if let score = viewModel.score {
            VStack(spacing: 20) {
                Text("Color Match")
                    .font(.largeTitle)
                    .bold()

                Text(score / 100, format: .percent.precision(.fractionLength(2)))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Higher percentages mean a closer match.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)

                if let round = viewModel.round, let result = viewModel.mixResult {
                    HStack(spacing: 16) {
                        VStack(alignment: .center, spacing: 8) {
                            Text("Your Mix")
                                .font(.headline)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: result.x, green: result.y, blue: result.z))
                                .frame(height: 120)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(.primary, lineWidth: 1)
                                }
                        }

                        VStack(alignment: .center, spacing: 8) {
                            Text("Target")
                                .font(.headline)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: round.request.targetSRGB.x, green: round.request.targetSRGB.y, blue: round.request.targetSRGB.z))
                                .frame(height: 120)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(.primary, lineWidth: 1)
                                }
                        }
                    }
                    .frame(maxWidth: 400)
                    .padding(.bottom, 32)
                }

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
    viewModel.score = 87.76
    return ScoreView(viewModel: viewModel)
}
