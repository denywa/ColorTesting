import SwiftUI

struct ScoreView: View {
    let viewModel: GameViewModel
    let coordinator: LocalPlayCoordinator?

    init(viewModel: GameViewModel, coordinator: LocalPlayCoordinator? = nil) {
        self.viewModel = viewModel
        self.coordinator = coordinator
    }

    var showsNewRound: Bool {
        coordinator == nil || coordinator?.role == .host
    }
    var newRoundDisabled: Bool { coordinator?.paused == true }
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
            coordinator.perform(.newRound)
        } else {
            viewModel.startNewRound()
        }
    }

    var body: some View {
        if let score = viewModel.score {
            VStack(spacing: 20) {
                Text("Color Match")
                    .font(.largeTitle)
                    .bold()

                if let pauseStatus {
                    Text(pauseStatus)
                        .font(.headline)
                        .accessibilityLabel(pauseStatus)
                }

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

                if showsNewRound {
                    Button("New Round", action: newRound)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(newRoundDisabled)
                }
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
