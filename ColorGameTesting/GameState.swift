import Foundation

struct PlayerAssignment {
    let player: PlayerID
    var primaryColor: NamedColor
    var secondaryColor: NamedColor
}

struct ColorUnit {
    let color: NamedColor
}

struct Mix {
    var units: [ColorUnit] = []
    var isLocked: Bool = false

    var ratios: [UUID: Double] {
        guard !units.isEmpty else { return [:] }
        let total = Double(units.count)
        var counts: [UUID: Int] = [:]
        for unit in units {
            counts[unit.color.id, default: 0] += 1
        }
        return counts.mapValues { Double($0) / total }
    }
}

struct Round {
    let request: ColorRequest
    let colorModel: ColorModel
    let mixMode: MixMode
    var assignments: [PlayerID: PlayerAssignment]
    var mix: Mix
}

struct GameState {
    var selectedModel: ColorModel = .ryb
    var selectedMixMode: MixMode = .manual
    var round: Round? = nil
    var mixResult: SIMD3<Double>? = nil
    var score: Double? = nil
}
