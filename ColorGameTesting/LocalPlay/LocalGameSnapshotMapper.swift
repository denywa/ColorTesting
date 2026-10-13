import Foundation

@MainActor
struct LocalGameSnapshotMapper {
    func makeSnapshot(from viewModel: GameViewModel, session: SessionState) throws -> GameSnapshot {
        let round = viewModel.round
        let mix = round?.mix.units ?? []
        var counts: [UUID: Int] = [:]
        var order: [UUID] = []
        for unit in mix {
            if counts[unit.color.id] == nil { order.append(unit.color.id) }
            counts[unit.color.id, default: 0] += 1
        }
        let snapshot = GameSnapshot(
            protocolVersion: LocalPlayProtocol.version,
            sessionID: session.sessionID,
            snapshotRevision: session.snapshotRevision,
            phase: viewModel.phase,
            roundID: viewModel.roundID,
            selectedModel: viewModel.selectedModel,
            mixMode: round?.mixMode ?? viewModel.selectedMixMode,
            target: round.map { .init(id: $0.request.id, text: $0.request.text,
                                      sRGB: .init($0.request.targetSRGB)) },
            reassignmentDuration: viewModel.reassignmentDuration,
            showTargetColor: viewModel.showTargetColor,
            timerSecondsRemaining: viewModel.timerSecondsRemaining,
            assignmentEpoch: viewModel.assignmentEpoch,
            assignments: PlayerID.allCases.compactMap { player in
                round?.assignments[player].map {
                    .init(player: player, primaryColorID: $0.primaryColor.id,
                          secondaryColorID: $0.secondaryColor.id)
                }
            },
            mixEntries: order.map { .init(colorID: $0, count: counts[$0]!) },
            mixLocked: round?.mix.isLocked ?? false,
            mixResult: viewModel.mixResult.map(GameSnapshot.RGB.init),
            currentBlend: viewModel.currentBlend.map(GameSnapshot.RGB.init),
            voting: nil,
            score: viewModel.score,
            paused: session.paused,
            seatStatus: session.seats.map { .init(player: $0.role.playerID, status: $0.status) }
        )
        _ = try state(from: snapshot)
        return snapshot
    }

    func apply(_ snapshot: GameSnapshot, to viewModel: GameViewModel) throws {
        guard viewModel.isLocalClient else { throw LocalPlayError.invalidSession }
        let state = try state(from: snapshot)
        viewModel.applyRemoteState(state, phase: snapshot.phase,
                                   timerSecondsRemaining: snapshot.timerSecondsRemaining,
                                   reassignmentDuration: snapshot.reassignmentDuration,
                                   showTargetColor: snapshot.showTargetColor,
                                   roundID: snapshot.roundID,
                                   assignmentEpoch: snapshot.assignmentEpoch)
    }

    private func state(from snapshot: GameSnapshot) throws -> GameState {
        guard snapshot.protocolVersion == LocalPlayProtocol.version,
              snapshot.snapshotRevision >= 0,
              (1...3600).contains(snapshot.reassignmentDuration),
              (0...snapshot.reassignmentDuration).contains(snapshot.timerSecondsRemaining),
              snapshot.seatStatus.count <= PlayerID.allCases.count,
              snapshot.seatStatus.contains(where: { $0.player == .player1 }),
              Set(snapshot.seatStatus.map(\.player)).count == snapshot.seatStatus.count,
              snapshot.score.map({ $0.isFinite && (0...100).contains($0) }) ?? true,
              snapshot.mixResult.map({ $0.isValidColor }) ?? true else {
            throw LocalPlayError.invalidMessage
        }
        if snapshot.phase == .settings {
            guard snapshot.roundID == nil, snapshot.target == nil,
                  snapshot.assignmentEpoch == nil, snapshot.assignments.isEmpty,
                  snapshot.mixEntries.isEmpty, !snapshot.mixLocked,
                  snapshot.mixResult == nil, snapshot.score == nil,
                  !snapshot.paused else { throw LocalPlayError.invalidMessage }
            return GameState()
        }

        guard let model = snapshot.selectedModel, let target = snapshot.target,
              snapshot.roundID != nil, let epoch = snapshot.assignmentEpoch,
              epoch >= 0, !target.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              target.sRGB.isValidColor,
              snapshot.assignments.count == PlayerID.allCases.count,
              Set(snapshot.assignments.map(\.player)).count == PlayerID.allCases.count else {
            throw LocalPlayError.invalidMessage
        }
        let palette = Dictionary(uniqueKeysWithValues: ColorData.colors(for: model).map { ($0.id, $0) })
        var assignments: [PlayerID: PlayerAssignment] = [:]
        for entry in snapshot.assignments {
            guard let primary = palette[entry.primaryColorID],
                  let secondary = palette[entry.secondaryColorID] else {
                throw LocalPlayError.invalidMessage
            }
            assignments[entry.player] = PlayerAssignment(player: entry.player,
                                                         primaryColor: primary,
                                                         secondaryColor: secondary)
        }
        var units: [ColorUnit] = []
        var orderedColors: [(NamedColor, Int)] = []
        var seen: Set<UUID> = []
        var totalUnits = 0
        for entry in snapshot.mixEntries {
            guard let color = palette[entry.colorID], entry.count > 0,
                  !seen.contains(entry.colorID), entry.count <= 10_000 - totalUnits else {
                throw LocalPlayError.invalidMessage
            }
            seen.insert(entry.colorID)
            totalUnits += entry.count
            orderedColors.append((color, entry.count))
            units.append(ColorUnit(color: color))
        }
        for (color, count) in orderedColors {
            units.append(contentsOf: repeatElement(ColorUnit(color: color), count: count - 1))
        }
        switch snapshot.phase {
        case .settings:
            throw LocalPlayError.invalidMessage
        case .playing:
            guard !snapshot.mixLocked, snapshot.mixResult == nil, snapshot.score == nil else {
                throw LocalPlayError.invalidMessage
            }
        case .result:
            guard snapshot.mixLocked, !units.isEmpty,
                  snapshot.mixResult != nil, snapshot.score == nil else {
                throw LocalPlayError.invalidMessage
            }
        case .score:
            guard snapshot.mixLocked, !units.isEmpty,
                  snapshot.mixResult != nil, snapshot.score != nil else {
                throw LocalPlayError.invalidMessage
            }
        }
        let request = ColorRequest(id: target.id, text: target.text, targetSRGB: target.sRGB.vector)
        let round = Round(request: request, colorModel: model, mixMode: .manual, assignments: assignments,
                          mix: Mix(units: units, isLocked: snapshot.mixLocked))
        return GameState(selectedModel: model, round: round,
                         mixResult: snapshot.mixResult?.vector, score: snapshot.score)
    }
}

private extension GameSnapshot.RGB {
    init(_ color: SIMD3<Double>) {
        self.init(red: color.x, green: color.y, blue: color.z)
    }

    var vector: SIMD3<Double> { SIMD3(red, green, blue) }
    var isValidColor: Bool {
        [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}
