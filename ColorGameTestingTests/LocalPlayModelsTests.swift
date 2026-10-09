import Foundation
import XCTest
@testable import ColorGameTesting

final class LocalPlayModelsTests: XCTestCase {
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let roundID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let colorID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    @MainActor func testSessionSeatsAreUniqueAndBoundedToThreePlayers() throws {
        let host = SessionSeat(role: .host, clientID: UUID(), reconnectToken: nil, status: .connected)
        let second = SessionSeat(role: .player2, clientID: UUID(), reconnectToken: UUID(), status: .connected)
        let third = SessionSeat(role: .player3, clientID: UUID(), reconnectToken: UUID(), status: .disconnected)

        let state = try SessionState(sessionID: sessionID, seats: [host, second, third], paused: true, snapshotRevision: 12)
        XCTAssertEqual(state.seats.count, 3)
        XCTAssertEqual(Set(state.seats.map(\.role.playerID)).count, 3)
        XCTAssertEqual(state.seats.last?.status, .disconnected)
        XCTAssertThrowsError(try SessionState(sessionID: sessionID, seats: [second], paused: false, snapshotRevision: 0))
        XCTAssertThrowsError(try SessionState(sessionID: sessionID, seats: [host, second, second], paused: false, snapshotRevision: 0))
        XCTAssertThrowsError(try SessionState(sessionID: sessionID, seats: [host, second, third, third], paused: false, snapshotRevision: 0))
        XCTAssertThrowsError(try SessionState(sessionID: sessionID, seats: [host, SessionSeat(role: .player2, clientID: host.clientID, reconnectToken: UUID(), status: .connected)], paused: false, snapshotRevision: 0))
        XCTAssertThrowsError(try SessionState(sessionID: sessionID, seats: [host, second, SessionSeat(role: .player3, clientID: UUID(), reconnectToken: second.reconnectToken, status: .connected)], paused: false, snapshotRevision: 0))
    }

    @MainActor func testSnapshotPreservesSharedRoundFieldsThroughCodable() throws {
        let snapshot = GameSnapshot(
            protocolVersion: LocalPlayProtocol.version,
            sessionID: sessionID,
            snapshotRevision: 42,
            phase: .playing,
            roundID: roundID,
            selectedModel: .ryb,
            target: .init(id: UUID(), text: "Lavender", sRGB: .init(red: 0.2, green: 0.3, blue: 0.4)),
            reassignmentDuration: 8,
            showTargetColor: true,
            timerSecondsRemaining: 4,
            assignmentEpoch: 2,
            assignments: [
                .init(player: .player1, primaryColorID: colorID, secondaryColorID: UUID()),
                .init(player: .player2, primaryColorID: UUID(), secondaryColorID: UUID()),
                .init(player: .player3, primaryColorID: UUID(), secondaryColorID: UUID())
            ],
            mixEntries: [.init(colorID: colorID, count: 3), .init(colorID: UUID(), count: 1)],
            mixLocked: false,
            mixResult: .init(red: 0.1, green: 0.2, blue: 0.3),
            score: 78.5,
            paused: true,
            seatStatus: [
                .init(player: .player1, status: .connected),
                .init(player: .player2, status: .connected),
                .init(player: .player3, status: .disconnected)
            ]
        )

        let copy = try JSONDecoder().decode(GameSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(copy.protocolVersion, LocalPlayProtocol.version)
        XCTAssertEqual(copy.sessionID, sessionID)
        XCTAssertEqual(copy.snapshotRevision, 42)
        XCTAssertEqual(copy.phase, .playing)
        XCTAssertEqual(copy.roundID, roundID)
        XCTAssertEqual(copy.selectedModel, .ryb)
        XCTAssertEqual(copy.target?.text, "Lavender")
        XCTAssertEqual(copy.target?.sRGB.blue, 0.4)
        XCTAssertEqual(copy.reassignmentDuration, 8)
        XCTAssertTrue(copy.showTargetColor)
        XCTAssertEqual(copy.timerSecondsRemaining, 4)
        XCTAssertEqual(copy.assignmentEpoch, 2)
        XCTAssertEqual(copy.assignments.map(\.player), [.player1, .player2, .player3])
        XCTAssertEqual(copy.mixEntries.map(\.count), [3, 1])
        XCTAssertEqual(copy.mixEntries.first?.colorID, colorID)
        XCTAssertFalse(copy.mixLocked)
        XCTAssertEqual(copy.mixResult?.red, 0.1)
        XCTAssertEqual(copy.score, 78.5)
        XCTAssertTrue(copy.paused)
        XCTAssertEqual(copy.seatStatus.last?.status, .disconnected)
    }

    @MainActor func testEveryWireMessageRoundTripsWithTypedPayload() throws {
        let actionID = UUID()
        let action = LocalGameAction.addColor(slot: .secondary, observedColorID: colorID, assignmentEpoch: 7)
        let messages: [WireMessage] = [
            .hello(.init(protocolVersion: LocalPlayProtocol.version, clientID: UUID(), sessionID: sessionID, reconnectToken: UUID())),
            .welcome(.init(sessionID: sessionID, role: .player2, reconnectToken: UUID())),
            .reject(.init(sessionID: sessionID, reason: .sessionFull)),
            .input(.init(sessionID: sessionID, roundID: roundID, actionID: actionID, action: action)),
            .snapshot(.init(protocolVersion: LocalPlayProtocol.version, sessionID: sessionID, snapshotRevision: 1, phase: .settings, roundID: nil, selectedModel: nil, target: nil, reassignmentDuration: 8, showTargetColor: false, timerSecondsRemaining: 8, assignmentEpoch: nil, assignments: [], mixEntries: [], mixLocked: false, mixResult: nil, score: nil, paused: false, seatStatus: [])),
            .heartbeat(.init(sessionID: sessionID, ping: 9)),
            .end(.init(sessionID: sessionID, reason: .hostEnded))
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        for message in messages {
            let data = try encoder.encode(message)
            let decoded = try JSONDecoder().decode(WireMessage.self, from: data)
            XCTAssertEqual(try encoder.encode(decoded), data)
        }
    }
}
