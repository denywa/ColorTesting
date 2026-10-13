import SwiftUI

struct ResultView: View {
    let viewModel: GameViewModel
    let coordinator: LocalPlayCoordinator?

    init(viewModel: GameViewModel, coordinator: LocalPlayCoordinator? = nil) {
        self.viewModel = viewModel
        self.coordinator = coordinator
    }

    var showsActions: Bool {
        coordinator == nil || coordinator?.role == .host
    }
    var actionsDisabled: Bool { coordinator?.paused == true }
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

    static func breakdown(for mix: Mix) -> [(color: NamedColor, percentage: Double, count: Int)] {
        var colors: [NamedColor] = []
        var counts: [UUID: Int] = [:]

        for unit in mix.units {
            if counts[unit.color.id] == nil {
                colors.append(unit.color)
            }
            counts[unit.color.id, default: 0] += 1
        }

        let ratios = mix.ratios
        return colors.map { color in
            let percentage = ((ratios[color.id] ?? 0) * 1_000).rounded() / 10
            return (color, percentage, counts[color.id] ?? 0)
        }
    }

    var body: some View {
        if let round = viewModel.round, let result = viewModel.mixResult {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Your Mix")
                        .font(.largeTitle)
                        .bold()

                    if let pauseStatus {
                        Text(pauseStatus)
                            .font(.headline)
                            .accessibilityLabel(pauseStatus)
                    }

                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: result.x, green: result.y, blue: result.z))
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.primary, lineWidth: 1)
                        }
                        .accessibilityLabel(
                            "Mixed color result, red \(Int((result.x * 100).rounded())) percent, " +
                            "green \(Int((result.y * 100).rounded())) percent, " +
                            "blue \(Int((result.z * 100).rounded())) percent"
                        )

                    Text("Color Breakdown")
                        .font(.title2)
                        .bold()

                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                        GridRow {
                            Text("Color")
                            Text("Percentage")
                                .gridColumnAlignment(.trailing)
                            Text("Units")
                                .gridColumnAlignment(.trailing)
                        }
                        .font(.headline)

                        ForEach(Self.breakdown(for: round.mix), id: \.color.id) { row in
                            GridRow {
                                Text(row.color.name)
                                Text("\(row.percentage.formatted(.number.precision(.fractionLength(1))))%")
                                Text(row.count, format: .number)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(
                                "\(row.color.name), \(row.percentage.formatted(.number.precision(.fractionLength(1)))) " +
                                "percent, \(row.count) units"
                            )
                        }
                    }
                    .font(.body)

                    if showsActions {
                        HStack(spacing: 16) {
                            Button("Redo", action: redo)
                                .buttonStyle(.bordered)
                            Button("Finish", action: finish)
                                .buttonStyle(.borderedProminent)
                        }
                        .font(.headline)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .disabled(actionsDisabled)
                    }
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        } else {
            ContentUnavailableView("No Mix Result", systemImage: "paintpalette")
        }
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
