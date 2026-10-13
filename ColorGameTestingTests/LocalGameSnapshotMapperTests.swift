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

        let active = try mapper.makeSnapshot(from: host, session: session(paused: true),
                                             voting: .init(id: UUID(), votes: [.init(player: .player1, action: .mix)]))
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
        let result = try mapper.makeSnapshot(from: host, session: session(),
                                             voting: .init(id: UUID(), votes: [
                                                .init(player: .player1, action: .finish),
                                                .init(player: .player2, action: .redo)
                                             ]))
        try mapper.apply(result, to: client)
        XCTAssertEqual(client.phase, .result)
        XCTAssertTrue(client.round?.mix.isLocked == true)
        XCTAssertEqual(client.mixResult, host.mixResult)

        host.selectFinish()
        let scored = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
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

        var snapshot = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
        XCTAssertNil(snapshot.roundID)
        XCTAssertNil(snapshot.target)
        XCTAssertNil(snapshot.assignmentEpoch)
        XCTAssertTrue(snapshot.assignments.isEmpty)
        try mapper.apply(snapshot, to: client)
        XCTAssertEqual(client.phase, .settings)
        XCTAssertEqual(client.selectedModel, .ryb)

        host.confirmSettings()
        let firstRoundID = try XCTUnwrap(host.roundID)
        XCTAssertThrowsError(try mapper.makeSnapshot(from: host, session: session(),
                                                     voting: .init(id: UUID(), votes: [.init(player: .player1, action: .mix)])))
        try mapper.apply(mapper.makeSnapshot(from: host, session: session(), voting: ballot(host)), to: client)
        XCTAssertNotNil(client.round)
        XCTAssertEqual(client.roundID, firstRoundID)
        host.addColor(player: .player1, slot: .primary)
        host.pressMixButton()
        host.selectFinish()
        host.startNewRound()
        snapshot = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
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

        host.confirmSettings()
        host.pauseTimer()
        let valid = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
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
        let scored = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
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

    private func ballot(_ model: GameViewModel) -> LocalVotingState? {
        model.phase == .playing || model.phase == .result ? .init(id: UUID(), votes: []) : nil
    }

    func testAutoLiveBlendCopiesHostValueAndMode() throws {
        let host = GameViewModel()
        let client = GameViewModel()
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
        defer { host.pauseTimer(); host.removeKeyMonitor(); client.removeKeyMonitor() }
        host.selectMixMode(.auto)
        host.confirmSettings()
        host.pauseTimer()
        host.addColor(player: .player1, slot: .primary)
        let snapshot = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
        let sentinel = try altered(snapshot, key: "currentBlend") { _ in
            ["red": 0.123, "green": 0.456, "blue": 0.789]
        }
        try mapper.apply(sentinel, to: client)
        XCTAssertEqual(client.selectedMixMode, .auto)
        XCTAssertEqual(client.round?.mixMode, .auto)
        XCTAssertEqual(client.currentBlend, SIMD3(0.123, 0.456, 0.789))
        XCTAssertNotEqual(client.currentBlend, host.currentBlend)
        for rgb: [String: Any] in [
            ["red": "NaN", "green": 0.2, "blue": 0.3],
            ["red": 0.2, "green": "Infinity", "blue": 0.3],
            ["red": 1.01, "green": 0.2, "blue": 0.3]
        ] {
            let invalid = try altered(sentinel, key: "currentBlend") { _ in rgb }
            XCTAssertThrowsError(try mapper.apply(invalid, to: client))
            XCTAssertEqual(client.currentBlend, SIMD3(0.123, 0.456, 0.789))
        }
        let missing = try altered(sentinel, key: "currentBlend") { _ in NSNull() }
        XCTAssertThrowsError(try mapper.apply(missing, to: client))
        XCTAssertEqual(client.currentBlend, SIMD3(0.123, 0.456, 0.789))
    }

    func testRejectsInvalidModeAssignmentsAndBallotsAtomically() throws {
        let host = GameViewModel()
        let client = GameViewModel()
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
        defer { host.pauseTimer(); host.removeKeyMonitor(); client.removeKeyMonitor() }
        host.confirmSettings()
        host.pauseTimer()
        host.addColor(player: .player1, slot: .primary)
        let snapshot = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
        try mapper.apply(snapshot, to: client)
        let badPair = try altered(snapshot, key: "assignments") { value in
            var entries = value as! [[String: Any]]
            entries[0]["secondaryColorID"] = entries[0]["primaryColorID"]
            return entries
        }
        let missing = try altered(snapshot, key: "voting") { _ in NSNull() }
        let badAction = try altered(snapshot, key: "voting") { _ in
            ["id": UUID().uuidString, "votes": [["player": "player1", "action": "apply"]]]
        }
        let majority = try altered(snapshot, key: "voting") { _ in
            ["id": UUID().uuidString, "votes": [["player": "player1", "action": "mix"], ["player": "player2", "action": "mix"]]]
        }
        let threeVotes = try altered(snapshot, key: "voting") { _ in
            ["id": UUID().uuidString, "votes": [["player": "player1", "action": "mix"],
                                                ["player": "player2", "action": "mix"],
                                                ["player": "player3", "action": "mix"]]]
        }
        for invalid in [badPair, missing, badAction, majority, threeVotes] {
            XCTAssertThrowsError(try mapper.apply(invalid, to: client))
            XCTAssertEqual(client.roundID, snapshot.roundID)
            XCTAssertEqual(client.round?.mix.units.count, 1)
            XCTAssertEqual(client.round?.assignments[.player1]?.secondaryColor.id,
                           host.round?.assignments[.player1]?.secondaryColor.id)
        }
    }

    func testValidPendingVotesSurvivePauseAndAutoScoreIsFrozen() throws {
        let host = GameViewModel()
        let client = GameViewModel()
        client.configureLocalPlay(localPlayer: .player3, isHost: false) { _, _ in }
        defer { host.pauseTimer(); host.removeKeyMonitor(); client.removeKeyMonitor() }
        host.selectMixMode(.auto)
        host.confirmSettings()
        host.pauseTimer()
        let empty = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
        try mapper.apply(empty, to: client)
        XCTAssertNil(client.currentBlend)
        let emptyLive = try altered(empty, key: "currentBlend") { _ in ["red": 0.1, "green": 0.2, "blue": 0.3] }
        XCTAssertThrowsError(try mapper.apply(emptyLive, to: client))
        let emptyVote = try altered(empty, key: "voting") { _ in
            ["id": UUID().uuidString, "votes": [["player": "player1", "action": "apply"]]]
        }
        XCTAssertThrowsError(try mapper.apply(emptyVote, to: client))
        host.addColor(player: .player1, slot: .primary)
        let pending = LocalVotingState(id: UUID(), votes: [
            .init(player: .player1, action: .apply), .init(player: .player3, action: .redo)
        ])
        let paused = try mapper.makeSnapshot(from: host, session: session(paused: true), voting: pending)
        try mapper.apply(paused, to: client)
        XCTAssertEqual(paused.voting?.id, pending.id)
        XCTAssertEqual(paused.voting?.votes.count, 2)
        XCTAssertEqual(client.currentBlend, host.currentBlend)
        let unpaused = try altered(paused, key: "paused") { _ in false }
        XCTAssertThrowsError(try mapper.apply(unpaused, to: client))
        host.selectApply()
        let score = try mapper.makeSnapshot(from: host, session: session(), voting: nil)
        try mapper.apply(score, to: client)
        XCTAssertEqual(client.phase, .score)
        XCTAssertNil(client.currentBlend)
        XCTAssertEqual(client.mixResult, host.mixResult)
        XCTAssertEqual(client.score, host.score)
        XCTAssertNil(score.voting)
        host.startNewRound()
        let settings = try mapper.makeSnapshot(from: host, session: session(), voting: nil)
        try mapper.apply(settings, to: client)
        XCTAssertEqual(client.selectedMixMode, .manual)
    }

    func testRejectsEveryPhaseAndNumericInvariantWithoutPartialApply() throws {
        let host = GameViewModel()
        let client = GameViewModel()
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
        defer { host.pauseTimer(); host.removeKeyMonitor(); client.removeKeyMonitor() }
        host.confirmSettings()
        host.pauseTimer()
        host.addColor(player: .player1, slot: .primary)
        let playing = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
        try mapper.apply(playing, to: client)
        let rgb = ["red": 0.2, "green": 0.3, "blue": 0.4]
        var invalid = try [
            altered(playing, key: "selectedModel") { _ in NSNull() },
            altered(playing, key: "currentBlend") { _ in rgb },
            altered(playing, key: "mixResult") { _ in rgb },
            altered(playing, key: "mixLocked") { _ in true },
            altered(playing, key: "score") { _ in 50 },
            altered(playing, key: "reassignmentDuration") { _ in 0 },
            altered(playing, key: "timerSecondsRemaining") { _ in playing.reassignmentDuration + 1 },
            altered(playing, key: "snapshotRevision") { _ in -1 },
            altered(playing, key: "assignments") { value in
                var entries = value as! [[String: Any]]
                entries[1] = entries[0]
                return entries
            },
            altered(playing, key: "assignments") { value in
                var entries = value as! [[String: Any]]
                let colors = ColorData.colors(for: .ryb)
                for index in entries.indices {
                    entries[index]["primaryColorID"] = colors[0].id.uuidString
                    entries[index]["secondaryColorID"] = colors[1].id.uuidString
                }
                return entries
            },
            altered(playing, key: "mixEntries") { _ in
                [["colorID": playing.mixEntries[0].colorID.uuidString, "count": 0]]
            },
            altered(playing, key: "mixEntries") { value in
                let entries = value as! [[String: Any]]
                return entries + entries
            },
            altered(playing, key: "voting") { _ in
                ["id": UUID().uuidString, "votes": [["player": "player1", "action": "mix"],
                                                    ["player": "player1", "action": "mix"]]]
            }
        ]
        let unknownVoter = try altered(playing, key: "seatStatus") { _ in
            [["player": "player1", "status": "connected"]]
        }
        invalid.append(try altered(unknownVoter, key: "voting") { _ in
            ["id": UUID().uuidString, "votes": [["player": "player2", "action": "mix"]]]
        })
        host.pressMixButton()
        let result = try mapper.makeSnapshot(from: host, session: session(), voting: ballot(host))
        invalid.append(try altered(result, key: "mixMode") { _ in "auto" })
        invalid.append(try altered(result, key: "mixLocked") { _ in false })
        invalid.append(try altered(result, key: "mixResult") { _ in NSNull() })
        invalid.append(try altered(result, key: "currentBlend") { _ in rgb })
        invalid.append(try altered(result, key: "mixResult") { _ in ["red": "NaN", "green": 0.3, "blue": 0.4] })
        host.selectFinish()
        let score = try mapper.makeSnapshot(from: host, session: session(), voting: nil)
        invalid.append(try altered(score, key: "voting") { _ in ["id": UUID().uuidString, "votes": []] })
        invalid.append(try altered(score, key: "currentBlend") { _ in rgb })
        invalid.append(try altered(score, key: "score") { _ in NSNull() })
        invalid.append(try altered(score, key: "score") { _ in "Infinity" })
        host.startNewRound()
        let settings = try mapper.makeSnapshot(from: host, session: session(), voting: nil)
        invalid.append(try altered(settings, key: "currentBlend") { _ in rgb })
        invalid.append(try altered(settings, key: "voting") { _ in ["id": UUID().uuidString, "votes": []] })
        for candidate in invalid {
            XCTAssertThrowsError(try mapper.apply(candidate, to: client))
            XCTAssertEqual(client.phase, .playing)
            XCTAssertEqual(client.roundID, playing.roundID)
            XCTAssertEqual(client.round?.mix.units.count, 1)
            XCTAssertEqual(client.timerSecondsRemaining, playing.timerSecondsRemaining)
            XCTAssertEqual(client.selectedMixMode, .manual)
        }
    }

    private func altered(_ snapshot: GameSnapshot, key: String, change: (Any?) -> Any) throws -> GameSnapshot {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        object[key] = change(object[key])
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try decoder.decode(GameSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
