import SwiftUI

struct GameView: View {
    let viewModel: GameViewModel
    let coordinator: LocalPlayCoordinator?
    var exitAction: (() -> Void)?
    @State private var showsRequestNotice = false
    @State private var automaticRequestNotice = true
    @Binding private var lastNoticedRoundID: UUID?

    init(viewModel: GameViewModel, coordinator: LocalPlayCoordinator? = nil, exitAction: (() -> Void)? = nil, lastNoticedRoundID: Binding<UUID?> = .constant(nil)) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.exitAction = exitAction
        _lastNoticedRoundID = lastNoticedRoundID
    }

    var visiblePlayers: [PlayerID] {
        guard let coordinator else { return PlayerID.allCases }
        return coordinator.role.map { [$0.playerID] } ?? []
    }
    var inputsDisabled: Bool { coordinator?.paused == true }
    var colorInputsDisabled: Bool { inputsDisabled || coordinator?.colorInputBlockedByVote == true }
    var showsMixButton: Bool { viewModel.round?.mixMode == .manual }
    var canMix: Bool { coordinator.map { $0.canVote(.mix) || $0.canCancelVote(.mix) } ?? viewModel.canMix }
    var canApply: Bool { coordinator.map { $0.canVote(.apply) || $0.canCancelVote(.apply) } ?? viewModel.canApply }
    var canRedo: Bool { coordinator.map { $0.canVote(.redo) || $0.canCancelVote(.redo) } ?? viewModel.canRedo }

    func apply() {
        if let coordinator { coordinator.toggleVote(.apply) } else { viewModel.selectApply() }
    }
    func redo() {
        if let coordinator { coordinator.toggleVote(.redo) } else { viewModel.selectRedo() }
    }
    func mix() {
        if let coordinator { coordinator.toggleVote(.mix) } else { viewModel.pressMixButton() }
    }

    private var pauseStatus: String? {
        guard inputsDisabled else { return nil }
        if let missing = coordinator?.seatStatus.first(where: { $0.status == .disconnected }) {
            return "Paused — waiting for Player \((PlayerID.allCases.firstIndex(of: missing.player) ?? 0) + 1) to reconnect"
        }
        return "Paused — waiting for connection"
    }

    var body: some View {
        GeometryReader { geometry in content(size: geometry.size) }
            .allowsHitTesting(!showsRequestNotice)
            .accessibilityHidden(showsRequestNotice)
            .overlay {
                if showsRequestNotice {
                    RequestNoticeView(request: viewModel.round?.request.text ?? "", message: requestNoticeMessage, title: automaticRequestNotice ? "NEW CLIENT" : "CLIENT REQUEST", targetHint: viewModel.showTargetColor ? viewModel.round?.request.targetSRGB : nil) {
                        showsRequestNotice = false
                    }
                }
            }
            .task(id: viewModel.roundID) {
                guard let id = viewModel.roundID, viewModel.run != nil, id != lastNoticedRoundID else { return }
                lastNoticedRoundID = id
                automaticRequestNotice = true
                showsRequestNotice = true
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                guard !Task.isCancelled, automaticRequestNotice else { return }
                showsRequestNotice = false
            }
    }

    private var requestNoticeMessage: String {
        if !automaticRequestNotice { return "Current client request" }
        if viewModel.run?.outcome == .timedOut {
            return viewModel.run?.configuration.mistakeLimit == nil ? "Time expired · new client" : "Time expired · 1 life lost · new client"
        }
        return "New client · Match their requested color"
    }

    private func showFullRequest() {
        automaticRequestNotice = false
        showsRequestNotice = true
    }

    @ViewBuilder func content(size: CGSize) -> some View {
        if let round = viewModel.round {
            layoutContent(round: round, size: size)
        } else {
            ContentUnavailableView("No Active Round", systemImage: "paintpalette")
        }
    }

    func layoutContent(round: Round, size: CGSize) -> some View {
        let sideWidth = min(190, max(120, size.width * 0.25))
        let cardHeight = min(100, max(70, size.height * 0.26))
        let bowlSize = max(80, min(PlaytestStyle.maximumBowlSize, size.height - (coordinator == nil ? PlaytestStyle.soloBowlAllowance : 160), size.width - sideWidth * 2 - 60))
        return VStack(spacing: 6) {
        RunHeaderView(run: viewModel.run, exitTitle: coordinator == nil || coordinator?.role == .host ? "Lobby" : "Leave",
                      exitAccessibilityLabel: coordinator == nil ? "Back to Settings" : coordinator?.role == .host ? "Back to Settings and Lobby" : "Leave Session", exitAction: exitAction)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                RequestCardView(request: round.request, showHint: viewModel.showTargetColor,
                                height: cardHeight, showFullRequest: showFullRequest)
                Spacer(minLength: 0)
                if let player = coordinator?.role?.playerID, let assignment = round.assignments[player] {
                    colorControl(assignment.primaryColor, player: player, slot: .primary, compact: false)
                        .disabled(colorInputsDisabled)
                }
            }
            .frame(width: sideWidth, alignment: .leading)
            VStack(spacing: 6) {
                if let pauseStatus {
                    Text(pauseStatus).font(.caption).multilineTextAlignment(.center)
                        .foregroundStyle(PlaytestStyle.accent).lineLimit(2)
                }
                Spacer(minLength: 0)
                bowl(round: round, size: bowlSize, showsMode: false)
                actions
                if let coordinator { LocalVotingStatusView(coordinator: coordinator, compact: true) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .trailing, spacing: 8) {
                Spacer(minLength: 0)
                if let player = coordinator?.role?.playerID, let assignment = round.assignments[player] {
                    colorControl(assignment.secondaryColor, player: player, slot: .secondary, compact: false)
                        .disabled(colorInputsDisabled)
                }
            }
            .frame(width: sideWidth, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
        if coordinator == nil { playerControls(round: round) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func playerControls(round: Round) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(visiblePlayers, id: \.self) { player in
                if let assignment = round.assignments[player] {
                    VStack(spacing: 6) {
                        Text(playerName(player)).font(.caption.bold())
                        HStack(spacing: 6) {
                            colorControl(assignment.primaryColor, player: player, slot: .primary, compact: true)
                            colorControl(assignment.secondaryColor, player: player, slot: .secondary, compact: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .disabled(colorInputsDisabled)
    }

    private func bowl(round: Round, size: CGFloat, showsMode: Bool = true) -> some View {
        VStack(spacing: 6) {
            MixingBowlView(size: size, mix: round.mixMode == .manual ? round.mix : nil,
                           color: viewModel.currentBlend,
                           emptyMessage: showsMode ? "Add a color to start mixing" : "Add a color")
            if showsMode {
                Text(round.mixMode == .manual ? "MANUAL MIX" : "AUTO MIX")
                    .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(PlaytestStyle.muted)
            }
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 10) {
            if showsMixButton {
                Button(coordinator?.canCancelVote(.mix) == true ? "Cancel Mix" : "Mix", action: mix).buttonStyle(PlaytestButtonStyle()).disabled(!canMix)
            } else {
                Button(coordinator?.canCancelVote(.redo) == true ? "Cancel Redo" : "Redo", action: redo).buttonStyle(PlaytestButtonStyle(primary: false)).disabled(!canRedo)
                Button(coordinator?.canCancelVote(.apply) == true ? "Cancel Apply" : "Apply", action: apply).buttonStyle(PlaytestButtonStyle()).disabled(!canApply)
            }
        }
    }

    private func colorControl(_ color: NamedColor, player: PlayerID, slot: ColorSlot, compact: Bool) -> some View {
        Button { viewModel.addColor(player: player, slot: slot) } label: {
            VStack(spacing: 5) {
                Circle().fill(Color(red: color.sRGB.x, green: color.sRGB.y, blue: color.sRGB.z))
                    .frame(width: compact ? 48 : 76, height: compact ? 48 : 76)
                    .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 2))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                Text(color.name).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                #if os(macOS)
                Text("Key \(slot == .primary ? player.keyLabels.0 : player.keyLabels.1)")
                    .font(.caption2.monospaced()).foregroundStyle(PlaytestStyle.muted)
                #endif
            }
            .frame(minWidth: 50, minHeight: 70)
            .padding(.horizontal, compact ? 4 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(playerName(player)), add \(color.name), \(slot == .primary ? "first" : "second") color")
        .accessibilityHint("Adds one unit to the shared mix")
    }

    private func playerName(_ player: PlayerID) -> String { "Player \((PlayerID.allCases.firstIndex(of: player) ?? 0) + 1)" }
    private func colorDescription(_ color: SIMD3<Double>) -> String {
        "Red \(Int((color.x * 100).rounded())) percent, green \(Int((color.y * 100).rounded())) percent, blue \(Int((color.z * 100).rounded())) percent"
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
