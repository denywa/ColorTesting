import SwiftUI

struct ResultView: View {
    let viewModel: GameViewModel
    let coordinator: LocalPlayCoordinator?
    var exitAction: (() -> Void)?
    @State private var showingFullRequest = false

    init(viewModel: GameViewModel, coordinator: LocalPlayCoordinator? = nil, exitAction: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.exitAction = exitAction
    }

    var showsActions: Bool {
        viewModel.round?.mixMode == .manual
    }
    var actionsDisabled: Bool {
        if let coordinator { return !coordinator.canVote(.finish) && !coordinator.canVote(.redo) }
        return false
    }
    var canRedo: Bool { coordinator?.canVote(.redo) ?? viewModel.canRedo }
    var canFinish: Bool { coordinator?.canVote(.finish) ?? viewModel.canFinish }
    var pauseStatus: String? {
        guard coordinator?.paused == true else { return nil }
        if let missing = coordinator?.seatStatus.first(where: { $0.status == .disconnected }) {
            let number = (PlayerID.allCases.firstIndex(of: missing.player) ?? 0) + 1
            return "Paused — waiting for Player \(number) to reconnect"
        }
        return "Paused — waiting for connection"
    }

    func redo() {
        if let coordinator {
            coordinator.castVote(.redo)
        } else {
            viewModel.selectRedo()
        }
    }
    func finish() {
        if let coordinator {
            coordinator.castVote(.finish)
        } else {
            viewModel.selectFinish()
        }
    }

    static func breakdown(for mix: Mix) -> [(color: NamedColor, count: Int)] {
        var colors: [NamedColor] = []
        var counts: [UUID: Int] = [:]

        for unit in mix.units {
            if counts[unit.color.id] == nil {
                colors.append(unit.color)
            }
            counts[unit.color.id, default: 0] += 1
        }

        return colors.map { ($0, counts[$0.id] ?? 0) }
    }

    var body: some View {
        Group {
        if let round = viewModel.round, let result = viewModel.mixResult {
            GeometryReader { geometry in
                layoutContent(round: round, result: result, size: geometry.size)
            }
        } else {
            ContentUnavailableView("No Mix Result", systemImage: "paintpalette")
        }
        }
        .allowsHitTesting(!showingFullRequest)
        .accessibilityHidden(showingFullRequest)
        .overlay {
            if showingFullRequest {
                RequestNoticeView(request: viewModel.round?.request.text ?? "", message: "Current client request", targetHint: viewModel.showTargetColor ? viewModel.round?.request.targetSRGB : nil) {
                    showingFullRequest = false
                }
            }
        }
    }

    func layoutContent(round: Round, result: SIMD3<Double>, size: CGSize) -> some View {
        let sideWidth = min(190, max(120, size.width * 0.25))
        let cardHeight = min(100, max(70, size.height * 0.26))
        let bowlSize = max(80, min(PlaytestStyle.maximumBowlSize, size.height - (coordinator == nil ? PlaytestStyle.soloBowlAllowance : 160), size.width - sideWidth * 2 - 60))
        let counts = Dictionary(uniqueKeysWithValues: Self.breakdown(for: round.mix).map { ($0.color.id, $0.count) })
        let dotSize = max(14, min(24, (size.height - 180) / 5))
        let actionWidth = min(220, max(sideWidth, size.width * 0.35))
        return VStack(spacing: 6) {
            RunHeaderView(run: viewModel.run, exitTitle: coordinator == nil || coordinator?.role == .host ? "Lobby" : "Leave",
                          exitAccessibilityLabel: coordinator == nil ? "Back to Settings" : coordinator?.role == .host ? "Back to Settings and Lobby" : "Leave Session", exitAction: exitAction)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    RequestCardView(request: round.request, showHint: viewModel.showTargetColor,
                                    height: cardHeight, showFullRequest: { showingFullRequest = true })
                    Spacer(minLength: 0)
                }
                .frame(width: sideWidth)
                VStack(spacing: 6) {
                    if let pauseStatus {
                        Text(pauseStatus).font(.caption).multilineTextAlignment(.center).lineLimit(2)
                            .foregroundStyle(PlaytestStyle.accent)
                    }
                    Spacer(minLength: 0)
                    MixingBowlView(size: bowlSize, color: result)
                    Text("YOUR MIX").font(.headline)
                        .padding(.horizontal, 22).frame(height: 44)
                        .background(PlaytestStyle.accent.opacity(0.1), in: Capsule())
                        .accessibilityAddTraits(.isHeader)
                    if coordinator != nil { Color.clear.frame(height: 21).accessibilityHidden(true) }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, coordinator == nil ? PlaytestStyle.soloKeyboardRowHeight : 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(ColorData.rybPalette) { color in
                            let count = counts[color.id, default: 0]
                            HStack(spacing: 10) {
                                Circle().fill(Color(red: color.sRGB.x, green: color.sRGB.y, blue: color.sRGB.z))
                                    .frame(width: dotSize, height: dotSize)
                                    .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 1.5))
                                Text("\(count)").font(.caption.bold().monospacedDigit())
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(color.name), \(count) \(count == 1 ? "unit" : "units")")
                        }
                    }
                    .padding(.bottom, coordinator == nil ? PlaytestStyle.soloKeyboardRowHeight : 0)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if let coordinator { LocalVotingStatusView(coordinator: coordinator, compact: true) }
                        if showsActions {
                            HStack(spacing: 10) {
                                Button(action: redo) { Text("Redo").frame(maxWidth: .infinity) }
                                    .buttonStyle(PlaytestButtonStyle(primary: false)).disabled(!canRedo)
                                Button(action: finish) { Text("Finish").frame(maxWidth: .infinity) }
                                    .buttonStyle(PlaytestButtonStyle()).disabled(!canFinish)
                            }
                        }
                    }
                    .frame(width: actionWidth)
                    .frame(width: sideWidth, alignment: .trailing)
                }
                .frame(width: sideWidth)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


}

#Preview {
    let viewModel = GameViewModel()
    let colors = ColorData.rybPalette
    let units = [
        ColorUnit(color: colors[0]), ColorUnit(color: colors[1]),
        ColorUnit(color: colors[1]), ColorUnit(color: colors[2])
    ]
    viewModel.phase = .result
    viewModel.round = Round(
        request: ColorData.requestPool[0],
        colorModel: .ryb,
        mixMode: .manual,
        assignments: [:],
        mix: Mix(units: units, isLocked: true)
    )
    viewModel.mixResult = ColorMixer.blend(units, model: .ryb)
    return ResultView(viewModel: viewModel)
}
