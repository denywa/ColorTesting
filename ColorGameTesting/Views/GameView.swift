import SwiftUI

struct GameView: View {
    let viewModel: GameViewModel
    let coordinator: LocalPlayCoordinator?

    init(viewModel: GameViewModel, coordinator: LocalPlayCoordinator? = nil) {
        self.viewModel = viewModel
        self.coordinator = coordinator
    }

    var visiblePlayers: [PlayerID] {
        guard let coordinator else { return PlayerID.allCases }
        return coordinator.role.map { [$0.playerID] } ?? []
    }

    var inputsDisabled: Bool { coordinator?.paused == true }
    var showsMixButton: Bool {
        (viewModel.round?.mixMode == .manual) &&
        (coordinator == nil || coordinator?.role == .host)
    }

    var canMix: Bool {
        viewModel.canMix &&
        (coordinator == nil || (coordinator?.role == .host && !inputsDisabled))
    }

    var canApply: Bool { coordinator == nil && viewModel.canApply }
    var canRedo: Bool { coordinator == nil && viewModel.canRedo }

    func apply() {
        guard canApply else { return }
        viewModel.selectApply()
    }

    func redo() {
        guard canRedo else { return }
        viewModel.selectRedo()
    }

    func mix() {
        if let coordinator {
            _ = coordinator.castVote(.mix)
        } else {
            viewModel.pressMixButton()
        }
    }

    private var roleTitle: String? {
        switch coordinator?.role {
        case .host: "Player 1 (Host)"
        case .player2: "Player 2"
        case .player3: "Player 3"
        case nil: nil
        }
    }

    private var pauseStatus: String? {
        guard coordinator?.paused == true else { return nil }
        if let missing = coordinator?.seatStatus.first(where: { $0.status == .disconnected }) {
            let number = (PlayerID.allCases.firstIndex(of: missing.player) ?? 0) + 1
            return "Paused — waiting for Player \(number) to reconnect"
        }
        return "Paused — waiting for connection"
    }

    private var chartSize: CGFloat {
        #if os(iOS)
        180
        #else
        240
        #endif
    }

    private var contentSpacing: CGFloat {
        #if os(iOS)
        16
        #else
        24
        #endif
    }

    private var requestFontSize: CGFloat {
        #if os(iOS)
        32
        #else
        36
        #endif
    }

    private var chartVerticalPadding: CGFloat? {
        #if os(iOS)
        4
        #else
        nil
        #endif
    }

    var body: some View {
        if let round = viewModel.round {
            ScrollView {
                VStack(alignment: .center, spacing: contentSpacing) {
                    if let roleTitle {
                        Text("Your role: \(roleTitle)")
                            .font(.headline)
                            .accessibilityLabel("Your role: \(roleTitle)")
                    }
                    if let pauseStatus {
                        Text(pauseStatus)
                            .font(.headline)
                            .accessibilityLabel(pauseStatus)
                    }
                    VStack(alignment: .center, spacing: 8) {
                        Text("Request")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Text(round.request.text)
                                .font(.system(size: requestFontSize, weight: .bold))
                                .minimumScaleFactor(0.7)
                                .lineLimit(2)
                            
                            if viewModel.showTargetColor {
                                Circle()
                                    .fill(Color(red: round.request.targetSRGB.x, green: round.request.targetSRGB.y, blue: round.request.targetSRGB.z))
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().strokeBorder(.primary, lineWidth: 1))
                            }
                        }
                    }

                    if round.mixMode == .auto {
                        if let color = viewModel.currentBlend {
                            Circle()
                                .fill(Color(red: color.x, green: color.y, blue: color.z))
                                .frame(width: chartSize, height: chartSize)
                                .overlay(Circle().strokeBorder(.primary, lineWidth: 1))
                                .accessibilityLabel(
                                    "Current blended color, red \(Int((color.x * 100).rounded())) percent, " +
                                    "green \(Int((color.y * 100).rounded())) percent, " +
                                    "blue \(Int((color.z * 100).rounded())) percent"
                                )
                        } else {
                            Text("Add a color to start mixing")
                                .foregroundStyle(.secondary)
                                .frame(width: chartSize, height: chartSize)
                        }
                    } else {
                        ColorBarView(mix: round.mix)
                            .frame(width: chartSize, height: chartSize)
                            .padding(.vertical, chartVerticalPadding)
                    }

                    Group {
                        #if os(iOS)
                        VStack(spacing: 10) {
                            ForEach(visiblePlayers, id: \.self) { player in
                                PlayerAssignmentPanel(viewModel: viewModel, player: player)
                            }
                        }
                        #else
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(visiblePlayers, id: \.self) { player in
                                    PlayerAssignmentPanel(viewModel: viewModel, player: player)
                                }
                            }
                            VStack(spacing: 16) {
                                ForEach(visiblePlayers, id: \.self) { player in
                                    PlayerAssignmentPanel(viewModel: viewModel, player: player)
                                }
                            }
                        }
                        #endif
                    }
                    .disabled(inputsDisabled)
                    .opacity(inputsDisabled ? 0.5 : 1)

                    HStack {
                        TimerBadge(secondsRemaining: viewModel.timerSecondsRemaining)
                        Spacer()
                        if round.mixMode == .auto {
                            Button("Redo", action: redo)
                                .buttonStyle(.bordered)
                                .disabled(!canRedo)
                            Button("Apply", action: apply)
                                .buttonStyle(.borderedProminent)
                                .disabled(!canApply)
                        } else if showsMixButton {
                            MixButton(isDisabled: !canMix, action: mix)
                        }
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

    private var colorSpacing: CGFloat {
        #if os(iOS)
        12
        #else
        16
        #endif
    }

    private var panelPadding: CGFloat {
        #if os(iOS)
        12
        #else
        16
        #endif
    }

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

                HStack(alignment: .top, spacing: colorSpacing) {
                    #if os(iOS)
                    ColorInputButton(color: assignment.primaryColor) {
                        viewModel.addColor(player: player, slot: .primary)
                    }
                    ColorInputButton(color: assignment.secondaryColor) {
                        viewModel.addColor(player: player, slot: .secondary)
                    }
                    #else
                    ColorKeySwatch(color: assignment.primaryColor, keyLabel: player.keyLabels.0)
                    ColorKeySwatch(color: assignment.secondaryColor, keyLabel: player.keyLabels.1)
                    #endif
                }
            }
            .padding(panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(playerTitle)
        }
    }
}

#if os(iOS)
private struct ColorInputButton: View {
    let color: NamedColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: color.sRGB.x, green: color.sRGB.y, blue: color.sRGB.z))
                    .frame(width: 42, height: 42)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.primary, lineWidth: 1)
                    }
                Text(color.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(color.name)")
        .accessibilityHint("Adds one unit to the mix")
    }
}
#else
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
#endif

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
    let colors = ColorData.rybPalette
    viewModel.phase = .playing
    viewModel.round = Round(
        request: ColorData.requestPool[0],
        colorModel: .ryb,
        mixMode: .manual,
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
