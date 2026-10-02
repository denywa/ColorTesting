import Foundation

enum KeyAction {
    case addColor(player: PlayerID, colorSlot: ColorSlot)
}

struct KeyRouter {
    static func action(for keyCode: UInt16) -> KeyAction? {
        switch keyCode {
        case KeyCode.q.rawValue: return .addColor(player: .player1, colorSlot: .primary)
        case KeyCode.w.rawValue: return .addColor(player: .player1, colorSlot: .secondary)
        case KeyCode.b.rawValue: return .addColor(player: .player2, colorSlot: .primary)
        case KeyCode.n.rawValue: return .addColor(player: .player2, colorSlot: .secondary)
        case KeyCode.o.rawValue: return .addColor(player: .player3, colorSlot: .primary)
        case KeyCode.p.rawValue: return .addColor(player: .player3, colorSlot: .secondary)
        default: return nil
        }
    }
}
