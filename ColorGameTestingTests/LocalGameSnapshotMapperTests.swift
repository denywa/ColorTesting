import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor
final class LocalGameSnapshotMapperTests: XCTestCase {
    private let mapper = LocalGameSnapshotMapper()

    private func session(paused: Bool = false) throws -> SessionState {
        try SessionState(sessionID: UUID(), seats: [
            SessionSeat(role: .host, clientID: UUID(), reconnectToken: nil, status: .connected),
            SessionSeat(role: .player2, clientID: UUID(), reconnectToken: UUID(), status: .connected),
            SessionSeat(role: .player3, clientID: UUID(), reconnectToken: UUID(), status: paused ? .disconnected : .connected)
        ], paused: paused, snapshotRevision: 7)
    }

    private func defaults() -> (UserDefaults, String) {
        let name = "ColorGameTestingTests.snapshot.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    func testRoundTripCustomTargetAssignmentsMixAndScoreWithoutPersistingClientCatalog() throws {
        let (hostDefaults, hostName) = defaults()
        let (clientDefaults, clientName) = defaults()
        defer {
            hostDefaults.removePersistentDomain(forName: hostName)
            clientDefaults.removePersistentDomain(forName: clientName)
        }
        let host = GameViewModel(requestDefaults: hostDefaults)
        let client = GameViewModel(requestDefaults: clientDefaults)
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
        defer { host.pauseTimer(); host.removeKeyMonitor(); client.pauseTimer(); client.removeKeyMonitor() }

        XCTAssertTrue(host.addCustomRequest(text: "Ocean dusk", hex: "#1766CC"))
        host.selectModel(.ryb)
        host.reassignmentDuration = 30
        host.showTargetColor = true
        host.confirmSettings()
        host.pauseTimer()
        host.timerSecondsRemaining = 9
        host.triggerReassignment()
        host.pauseTimer()
        host.timerSecondsRemaining = 9
        let colors = ColorData.colors(for: .ryb)
        var round = try XCTUnwrap(host.round)
        round.mix.units = [colors[2], colors[0], colors[2], colors[1], colors[0]].map(ColorUnit.init(color:))
        host.round = round

        let active = try mapper.makeSnapshot(from: host, session: session(paused: true))
        XCTAssertEqual(active.target?.text, "Ocean dusk")
        XCTAssertEqual(active.target?.sRGB.red, 23.0 / 255)
        XCTAssertEqual(active.assignmentEpoch, 1)
        XCTAssertEqual(active.mixEntries.map(\.colorID), [colors[2].id, colors[0].id, colors[1].id])
        XCTAssertEqual(active.mixEntries.map(\.count), [2, 2, 1])
        XCTAssertEqual(active.seatStatus.last?.status, .disconnected)
        try mapper.apply(active, to: client)
        XCTAssertEqual(client.phase, .playing)
        XCTAssertEqual(client.round?.request.id, host.round?.request.id)
        XCTAssertEqual(client.round?.request.text, "Ocean dusk")
        XCTAssertEqual(client.round?.request.targetSRGB, host.round?.request.targetSRGB)
        XCTAssertEqual(client.round?.assignments[.player2]?.primaryColor.id, host.round?.assignments[.player2]?.primaryColor.id)
        XCTAssertEqual(client.round?.mix.units.map(\.color.id), [colors[2].id, colors[0].id, colors[1].id, colors[2].id, colors[0].id])
        XCTAssertEqual(client.round?.mix.ratios, host.round?.mix.ratios)
        XCTAssertEqual(client.timerSecondsRemaining, 9)
        XCTAssertEqual(client.reassignmentDuration, 30)
        XCTAssertTrue(client.showTargetColor)
        XCTAssertTrue(client.customRequests.isEmpty)
        XCTAssertTrue(CustomRequestStore(defaults: clientDefaults).load().isEmpty)

        host.pressMixButton()
        let result = try mapper.makeSnapshot(from: host, session: session())
        try mapper.apply(result, to: client)
        XCTAssertEqual(client.phase, .result)
        XCTAssertTrue(client.round?.mix.isLocked == true)
        XCTAssertEqual(client.mixResult, host.mixResult)

        host.selectFinish()
        let scored = try mapper.makeSnapshot(from: host, session: session())
        try mapper.apply(scored, to: client)
        XCTAssertEqual(client.phase, .score)
        XCTAssertEqual(client.score, host.score)
        XCTAssertEqual(client.mixResult, host.mixResult)
        XCTAssertTrue(client.customRequests.isEmpty)
    }

    func testSettingsSnapshotAndNewRoundClearClientRound() throws {
        let host = GameViewModel()
        let client = GameViewModel()
        client.configureLocalPlay(localPlayer: .player3, isHost: false) { _, _ in }
        defer { host.pauseTimer(); host.removeKeyMonitor(); client.pauseTimer(); client.removeKeyMonitor() }
        host.selectModel(.cmyk)
        var snapshot = try mapper.makeSnapshot(from: host, session: session())
        XCTAssertNil(snapshot.roundID)
        XCTAssertNil(snapshot.target)
        XCTAssertNil(snapshot.assignmentEpoch)
        XCTAssertTrue(snapshot.assignments.isEmpty)
        try mapper.apply(snapshot, to: client)
        XCTAssertEqual(client.phase, .settings)
        XCTAssertEqual(client.selectedModel, .cmyk)

        host.confirmSettings()
        let firstRoundID = try XCTUnwrap(host.roundID)
        try mapper.apply(mapper.makeSnapshot(from: host, session: session()), to: client)
        XCTAssertNotNil(client.round)
        XCTAssertEqual(client.roundID, firstRoundID)
        host.addColor(player: .player1, slot: .primary)
        host.pressMixButton()
        host.selectFinish()
        host.startNewRound()
        snapshot = try mapper.makeSnapshot(from: host, session: session())
        try mapper.apply(snapshot, to: client)
        XCTAssertEqual(client.phase, .settings)
        XCTAssertNil(client.round)
        XCTAssertNil(client.roundID)
        XCTAssertNil(client.assignmentEpoch)
        XCTAssertNil(client.mixResult)
        XCTAssertNil(client.score)
    }

    func testRejectsUnknownPaletteIDsAndInvalidNumbersWithoutChangingClient() throws {
        let host = GameViewModel()
        let client = GameViewModel()
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
        defer { host.pauseTimer(); host.removeKeyMonitor(); client.pauseTimer(); client.removeKeyMonitor() }
        host.selectModel(.ryb)
        host.confirmSettings()
        host.pauseTimer()
        let valid = try mapper.makeSnapshot(from: host, session: session())
        try mapper.apply(valid, to: client)
        XCTAssertThrowsError(try mapper.apply(valid, to: host))
        let originalRoundID = client.roundID

        let badColor = try altered(valid, key: "assignments") { value in
            var assignments = value as! [[String: Any]]
            assignments[0]["primaryColorID"] = UUID().uuidString
            return assignments
        }
        XCTAssertThrowsError(try mapper.apply(badColor, to: client))
        let badTimer = try altered(valid, key: "timerSecondsRemaining") { _ in -1 }
        XCTAssertThrowsError(try mapper.apply(badTimer, to: client))
        let badMix = try altered(valid, key: "mixEntries") { _ in
            [["colorID": ColorData.colors(for: .ryb)[0].id.uuidString, "count": Int.max]]
        }
        XCTAssertThrowsError(try mapper.apply(badMix, to: client))
        let badEpoch = try altered(valid, key: "assignmentEpoch") { _ in -1 }
        XCTAssertThrowsError(try mapper.apply(badEpoch, to: client))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        var target = object["target"] as! [String: Any]
        target["sRGB"] = ["red": "NaN", "green": 0.2, "blue": 0.3]
        object["target"] = target
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let nonFinite = try decoder.decode(GameSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try mapper.apply(nonFinite, to: client))
        XCTAssertEqual(client.roundID, originalRoundID)
        XCTAssertEqual(client.round?.request.id, host.round?.request.id)
        XCTAssertTrue(client.round?.mix.units.isEmpty == true)

        host.addColor(player: .player1, slot: .primary)
        host.pressMixButton()
        host.selectFinish()
        let scored = try mapper.makeSnapshot(from: host, session: session())
        try mapper.apply(scored, to: client)
        let badScore = try altered(scored, key: "score") { _ in 101.0 }
        XCTAssertThrowsError(try mapper.apply(badScore, to: client))
        let badTarget = try altered(scored, key: "target") { value in
            var target = value as! [String: Any]
            target["sRGB"] = ["red": 1.5, "green": 0.2, "blue": 0.3]
            return target
        }
        XCTAssertThrowsError(try mapper.apply(badTarget, to: client))
        XCTAssertEqual(client.phase, .score)
        XCTAssertEqual(client.score, scored.score)
    }

    private func altered(_ snapshot: GameSnapshot, key: String, change: (Any?) -> Any) throws -> GameSnapshot {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        object[key] = change(object[key])
        return try JSONDecoder().decode(GameSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
