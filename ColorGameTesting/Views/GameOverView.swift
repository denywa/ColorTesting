import SwiftUI

struct GameOverView: View {
    let viewModel: GameViewModel
    var coordinator: LocalPlayCoordinator?
    private var controlsRun: Bool { coordinator == nil || coordinator?.role == .host }

    var body: some View {
        ScrollView {
            if let run = viewModel.run {
                VStack(alignment: .leading, spacing: 20) {
                    PlaytestHeading(title: "Game Over", subtitle: run.failure?.message ?? "The run has ended.")
                    RunStatusView(run: run)
                    Text("You reached Day \(run.day)").font(.title.bold())
                    if let score = viewModel.score {
                        Text("Last match: \(score.formatted(.number.precision(.fractionLength(2))))%")
                    }
                    if coordinator?.paused == true {
                        Text("Reconnect all players to restart, or return to the lobby.")
                            .font(.callout).foregroundStyle(PlaytestStyle.muted)
                    }
                    if controlsRun {
                        HStack(spacing: 12) {
                            Button("Lobby") { back() }
                                .buttonStyle(PlaytestButtonStyle(primary: false))
                            Button("Start Over") { restart() }
                                .buttonStyle(PlaytestButtonStyle()).disabled(coordinator?.paused == true)
                        }
                    } else { Text("Waiting for the host to restart or return to the lobby.") }
                }
                .playtestCard().padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }
        }
    }
    private func back() {
        if let coordinator { coordinator.perform(.returnToLobby) } else { viewModel.returnToSettings() }
    }
    private func restart() {
        if let coordinator { coordinator.perform(.restartRun) } else { viewModel.restartRun() }
    }
}
