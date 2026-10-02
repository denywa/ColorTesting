import SwiftUI

struct GameView: View {
    let viewModel: GameViewModel

    var body: some View {
        if let round = viewModel.round {
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .center, spacing: 8) {
                        Text("Request")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Text(round.request.text)
                                .font(.system(size: 36, weight: .bold))
                            
                            if viewModel.showTargetColor {
                                Circle()
                                    .fill(Color(red: round.request.targetSRGB.x, green: round.request.targetSRGB.y, blue: round.request.targetSRGB.z))
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().strokeBorder(.primary, lineWidth: 1))
                            }
                        }
                    }

                    ColorBarView(mix: round.mix)
                        .frame(width: 240, height: 240)
                        .padding(.vertical)

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(PlayerID.allCases, id: \.self) { player in
                                PlayerAssignmentPanel(viewModel: viewModel, player: player)
                            }
                        }

                        VStack(spacing: 16) {
                            ForEach(PlayerID.allCases, id: \.self) { player in
                                PlayerAssignmentPanel(viewModel: viewModel, player: player)
                            }
                        }
                    }

                    HStack {
                        TimerBadge(secondsRemaining: viewModel.timerSecondsRemaining)
                        Spacer()
                        MixButton(
                            isDisabled: viewModel.round?.mix.units.isEmpty ?? true,
                            action: viewModel.pressMixButton
                        )
                    }
                }
                .padding()
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)
            }
        } else {
            ContentUnavailableView("No Active Round", systemImage: "paintpalette")
        }
    }
}

private struct PlayerAssignmentPanel: View {
    let viewModel: GameViewModel
    let player: PlayerID

    private var playerTitle: String {
        switch player {
        case .player1: "Player 1"
        case .player2: "Player 2"
        case .player3: "Player 3"
        }
    }

    var body: some View {
        if let assignment = viewModel.round?.assignments[player] {
            VStack(alignment: .leading, spacing: 12) {
                Text(playerTitle)
                    .font(.headline)

                HStack(alignment: .top, spacing: 16) {
                    ColorKeySwatch(color: assignment.primaryColor, keyLabel: player.keyLabels.0)
                    ColorKeySwatch(color: assignment.secondaryColor, keyLabel: player.keyLabels.1)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(playerTitle)
        }
    }
}

private struct ColorKeySwatch: View {
    let color: NamedColor
    let keyLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: color.sRGB.x, green: color.sRGB.y, blue: color.sRGB.z))
                .frame(width: 64, height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.primary, lineWidth: 1)
                }
                .accessibilityLabel("\(color.name) color swatch")

            Text(color.name)
                .font(.body)
            Text("Key \(keyLabel)")
                .font(.headline.monospaced())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimerBadge: View {
    let secondsRemaining: Int

    var body: some View {
        Label("\(secondsRemaining) seconds", systemImage: "timer")
            .font(.headline)
            .padding(10)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Reassignment in \(secondsRemaining) seconds")
    }
}

private struct MixButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button("Mix", action: action)
            .font(.headline)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isDisabled)
    }
}

#Preview {
    let viewModel = GameViewModel()
    let colors = ColorData.cmykPalette
    viewModel.phase = .playing
    viewModel.selectedModel = .cmyk
    viewModel.round = Round(
        request: ColorData.requestPool[0],
        colorModel: .cmyk,
        assignments: [
            .player1: PlayerAssignment(player: .player1, primaryColor: colors[0], secondaryColor: colors[1]),
            .player2: PlayerAssignment(player: .player2, primaryColor: colors[2], secondaryColor: colors[3]),
            .player3: PlayerAssignment(player: .player3, primaryColor: colors[4], secondaryColor: colors[0])
        ],
        mix: Mix(units: [
            ColorUnit(color: colors[0]), ColorUnit(color: colors[1]),
            ColorUnit(color: colors[1]), ColorUnit(color: colors[2])
        ])
    )
    return GameView(viewModel: viewModel)
}
