import Foundation

enum LocalPlayProtocol {
    static let version = 3
}

enum PlayMode {
    case singleDevice
    case threeDevices
}

enum SessionRole: String, Codable, CaseIterable {
    case host, player2, player3

    var playerID: PlayerID {
        switch self {
        case .host: .player1
        case .player2: .player2
        case .player3: .player3
        }
    }
}

enum SessionStatus: String, Codable {
    case waiting, connected, disconnected
}

struct SessionSeat: Codable {
    let role: SessionRole
    let clientID: UUID
    let reconnectToken: UUID?
    var status: SessionStatus
}

struct SessionState {
    let sessionID: UUID
    let seats: [SessionSeat]
    var paused: Bool
    var snapshotRevision: Int

    init(sessionID: UUID, seats: [SessionSeat], paused: Bool, snapshotRevision: Int) throws {
        let roles = seats.map(\.role)
        let clientIDs = seats.map(\.clientID)
        let tokens = seats.compactMap(\.reconnectToken)
        guard roles.contains(.host), roles.count <= PlayerID.allCases.count,
              Set(roles).count == roles.count,
              Set(clientIDs).count == clientIDs.count,
              Set(tokens).count == tokens.count else {
            throw LocalPlayError.invalidSession
        }
        self.sessionID = sessionID
        self.seats = seats
        self.paused = paused
        self.snapshotRevision = snapshotRevision
    }
}

struct DiscoveredSession: Identifiable, Hashable {
    let id: UUID
    let name: String
}

struct PeerHandle: Hashable {
    let id: UUID
}

enum LocalVoteAction: String, Codable, CaseIterable {
    case mix, finish, apply, redo
}

struct LocalVotingState: Codable {
    struct Vote: Codable {
        let player: PlayerID
        let action: LocalVoteAction
    }

    let id: UUID
    var votes: [Vote]
}

extension MixMode: Codable {}

enum LocalGameAction: Codable {
    case startRound
    case startRun
    case continueRun
    case restartRun
    case returnToLobby
    case addColor(slot: ColorSlot, observedColorID: UUID, assignmentEpoch: Int)
    case vote(action: LocalVoteAction, votingID: UUID)
    case newRound
}

struct GameSnapshot: Codable {
    struct RGB: Codable {
        let red: Double
        let green: Double
        let blue: Double
    }

    struct Target: Codable {
        let id: UUID
        let text: String
        let sRGB: RGB
        var difficulty: RequestDifficulty = .level1
    }

    struct Assignment: Codable {
        let player: PlayerID
        let primaryColorID: UUID
        let secondaryColorID: UUID
    }

    struct MixEntry: Codable {
        let colorID: UUID
        let count: Int
    }

    struct SeatStatus: Codable {
        let player: PlayerID
        let status: SessionStatus
    }

    let protocolVersion: Int
    let sessionID: UUID
    let snapshotRevision: Int
    let phase: GamePhase
    let roundID: UUID?
    let selectedModel: ColorModel?
    let mixMode: MixMode
    let target: Target?
    let reassignmentDuration: Int
    let showTargetColor: Bool
    let timerSecondsRemaining: Int
    let assignmentEpoch: Int?
    let assignments: [Assignment]
    let mixEntries: [MixEntry]
    let mixLocked: Bool
    let mixResult: RGB?
    let currentBlend: RGB?
    let voting: LocalVotingState?
    let score: Double?
    let paused: Bool
    let seatStatus: [SeatStatus]
    var runConfiguration: EndlessRunConfiguration = .init()
    var run: EndlessRunState? = nil
}

enum WireMessage: Codable {
    struct Hello: Codable {
        let protocolVersion: Int
        let clientID: UUID
        let sessionID: UUID?
        let reconnectToken: UUID?
    }

    struct Welcome: Codable {
        let sessionID: UUID
        let role: SessionRole
        let reconnectToken: UUID
    }

    struct Reject: Codable {
        let sessionID: UUID
        let reason: LocalPlayError
    }

    struct Input: Codable {
        let sessionID: UUID
        let roundID: UUID
        let actionID: UUID
        let action: LocalGameAction
    }

    struct Heartbeat: Codable {
        let sessionID: UUID
        let ping: UInt64
    }

    enum EndReason: String, Codable {
        case hostEnded
    }

    struct End: Codable {
        let sessionID: UUID
        let reason: EndReason
    }

    case hello(Hello)
    case welcome(Welcome)
    case reject(Reject)
    case input(Input)
    case snapshot(GameSnapshot)
    case heartbeat(Heartbeat)
    case end(End)
}

enum LocalPlayError: String, Error, Codable {
    case permissionDenied
    case wifiUnavailable
    case sessionNotFound
    case sessionFull
    case versionMismatch
    case invalidMessage
    case invalidSession
    case disconnected
}

extension ColorModel: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let model = ColorModel(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown color model")
        }
        self = model
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension PlayerID: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "player1": self = .player1
        case "player2": self = .player2
        case "player3": self = .player3
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown player")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .player1: try container.encode("player1")
        case .player2: try container.encode("player2")
        case .player3: try container.encode("player3")
        }
    }
}

extension GamePhase: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "settings": self = .settings
        case "playing": self = .playing
        case "result": self = .result
        case "score": self = .score
        case "gameOver": self = .gameOver
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown phase")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .settings: try container.encode("settings")
        case .playing: try container.encode("playing")
        case .result: try container.encode("result")
        case .score: try container.encode("score")
        case .gameOver: try container.encode("gameOver")
        }
    }
}

extension ColorSlot: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "primary": self = .primary
        case "secondary": self = .secondary
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown color slot")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .primary: try container.encode("primary")
        case .secondary: try container.encode("secondary")
        }
    }
}
