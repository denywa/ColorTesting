import Foundation

enum ColorModel: String, CaseIterable {
    case cmyk = "CMYK"
    case ryb = "RYB"
}

enum PlayerID: CaseIterable {
    case player1, player2, player3

    /// The two physical keys assigned to this player.
    var keys: (primary: KeyCode, secondary: KeyCode) {
        switch self {
        case .player1: return (.q, .w)
        case .player2: return (.b, .n)
        case .player3: return (.o, .p)
        }
    }

    /// Human-readable key labels for display.
    var keyLabels: (String, String) {
        switch self {
        case .player1: return ("Q", "W")
        case .player2: return ("B", "N")
        case .player3: return ("O", "P")
        }
    }
}

enum KeyCode: UInt16 {
    case q = 12, w = 13, b = 11, n = 45, o = 31, p = 35
}

enum GamePhase {
    case settings
    case playing
    case result
    case score
}

enum ColorSlot {
    case primary, secondary
}

/// A named color defined in a specific color model's component space.
struct NamedColor: Identifiable, Hashable {
    let id: UUID
    let name: String
    let sRGB: SIMD3<Double>
    let cmykComponents: SIMD4<Double>?
    let rybComponents: SIMD3<Double>?
}
