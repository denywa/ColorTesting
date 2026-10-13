import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor
final class EndlessNetworkTests: XCTestCase {
    private final class Clock {
        var date = Date(timeIntervalSince1970: 20_000)
        var readStep = 0.0
        func read() -> Date { let value = date; date += readStep; return value }
        func advance(_ seconds: Double) { date += seconds }
    }
    private struct Group {
        let models: [GameViewModel]
        let peers: [LocalPlayCoordinator]
        let transports: [FakePeerTransport]
    }
    private func wait(_ predicate: () -> Bool) async {
        for _ in 0..<100 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Shared endless-run state did not converge")
    }
    private func group(_ clock: Clock, clientTimer: Bool = false) async throws -> Group {
        let network = FakePeerNetwork()
        let models = [GameViewModel(now: { clock.read() }), GameViewModel(), GameViewModel()]
        let transports = models.map { _ in network.makePeer() }
        let peers = models.indices.map { LocalPlayCoordinator(viewModel: models[$0], transport: transports[$0]) }
        try peers[0].startHosting()
        for i in 1...2 {
            peers[i].startBrowsing()
            peers[i].join(try XCTUnwrap(peers[i].discoveredSessions.first))
            await wait { peers[i].latestSnapshot != nil }
        }
        var config = EndlessRunConfiguration()
        config.timerMode = clientTimer ? .client : .day
        config.dayDuration = 30
        config.clientDuration = 5
        config.passingScore = 0
        config.templates = config.templates.map { .init(levels: [$0.levels.last!]) }
        models[0].runConfiguration = config
        models[0].selectMixMode(.auto)
        XCTAssertTrue(peers[0].perform(.startRun))
        await wait { models.allSatisfy { $0.run != nil && $0.phase == .playing } }
        return Group(models: models, peers: peers, transports: transports)
    }
    private func grade(_ group: Group) async {
        group.models[0].addColor(player: .player1, slot: .primary)
        await wait { group.models.allSatisfy { $0.round?.mix.units.count == 1 } }
        XCTAssertTrue(group.peers[0].castVote(.apply))
        await wait { group.peers[1].voting?.votes.count == 1 }
        XCTAssertTrue(group.peers[1].castVote(.apply))
        await wait { group.models.allSatisfy { $0.phase == .score } }
    }

    func testMajorityGradesAndHostContinuesThroughCapWhileClientsOnlyMirror() async throws {
        let clock = Clock()
        let team = try await group(clock)
        for day in 1...10 {
            XCTAssertEqual(team.models[0].run?.day, day)
            XCTAssertEqual(team.models[0].round?.request.difficulty,
                           team.models[0].run?.configuration.templates[EndlessRunConfiguration.templateIndex(for: day)].levels[0])
            await grade(team)
            XCTAssertTrue(team.models.allSatisfy { $0.run?.status == .dayComplete && $0.run?.completed == 1 })
            XCTAssertTrue(team.models.allSatisfy { $0.score == team.models[0].score })
            XCTAssertFalse(team.peers[1].perform(.continueRun))
            team.models[1].refreshRunBudget()
            XCTAssertEqual(team.models[1].run, team.models[0].run)
            XCTAssertTrue(team.peers[0].perform(.continueRun))
            await wait { team.models.allSatisfy { $0.phase == .playing && $0.run?.day == day + 1 } }
            XCTAssertTrue(team.peers.allSatisfy { $0.voting?.votes.isEmpty == true })
        }
        await team.peers[0].leaveSession()
    }

    func testTimeoutRotatesBallotRejectsOldVotesAndThirdTimeoutProducesSharedGameOver() async throws {
        let clock = Clock(), team = try await group(clock, clientTimer: true)
        let host = team.peers[0], model = team.models[0]
        model.addColor(player: .player1, slot: .primary)
        XCTAssertTrue(host.castVote(.apply))
        let oldRound = try XCTUnwrap(model.roundID), oldBallot = try XCTUnwrap(host.voting?.id)
        let target = model.round?.request.id
        clock.advance(5); model.refreshRunBudget()
        await wait { team.models.allSatisfy { $0.run?.mistakes == 1 && $0.round?.mix.units.isEmpty == true } }
        XCTAssertNotEqual(host.voting?.id, oldBallot)
        let stale = WireMessage.input(.init(sessionID: host.sessionID!, roundID: oldRound, actionID: UUID(),
                                             action: .vote(action: .apply, votingID: oldBallot)))
        try await team.transports[1].send(stale, to: team.transports[0].handle)
        XCTAssertTrue(host.voting?.votes.isEmpty == true)
        XCTAssertNotEqual(model.round?.request.id, target)
        for count in 2...3 {
            clock.advance(5); model.refreshRunBudget()
            await wait { team.models.allSatisfy { $0.run?.mistakes == count } }
        }
        XCTAssertTrue(team.models.allSatisfy { $0.phase == .gameOver && $0.score == nil })
        XCTAssertNil(host.error)
        XCTAssertTrue(team.peers.allSatisfy { $0.voting == nil })
        XCTAssertFalse(team.peers[1].perform(.restartRun))
        XCTAssertTrue(host.perform(.restartRun))
        await wait { team.models.allSatisfy { $0.phase == .playing && $0.run?.mistakes == 0 && $0.run?.day == 1 } }
        await host.leaveSession()
    }

    func testReconnectRestoresBudgetAndVotesAndReturnToLobbyKeepsSeatsEvenWhilePaused() async throws {
        let clock = Clock(), team = try await group(clock, clientTimer: true)
        let host = team.peers[0], model = team.models[0], session = host.sessionID
        model.addColor(player: .player1, slot: .primary)
        XCTAssertTrue(host.castVote(.apply))
        clock.advance(2); model.refreshRunBudget()
        await wait { team.models.allSatisfy { $0.run?.remainingSeconds == 3 } }
        let ballot = host.voting?.id
        team.transports[1].stop()
        await wait { host.paused && team.peers[2].paused }
        clock.advance(100); model.refreshRunBudget()
        XCTAssertEqual(model.run?.remainingSeconds, 3)
        XCTAssertEqual(model.run?.mistakes, 0)
        XCTAssertFalse(host.castVote(.apply))
        team.peers[1].startBrowsing()
        team.peers[1].join(try XCTUnwrap(team.peers[1].discoveredSessions.first))
        await wait { team.peers.allSatisfy { !$0.paused } }
        XCTAssertTrue(team.models.allSatisfy { $0.run?.remainingSeconds == 3 })
        XCTAssertTrue(team.peers.allSatisfy { $0.voting?.id == ballot && $0.voting?.votes.count == 1 })
        XCTAssertEqual(team.peers[1].role, .player2)
        clock.advance(2); model.refreshRunBudget()
        XCTAssertEqual(model.run?.remainingSeconds, 1)
        XCTAssertTrue(team.peers[1].castVote(.apply))
        await wait { team.models.allSatisfy { $0.phase == .score } }
        XCTAssertEqual(model.run?.mistakes, 0)
        XCTAssertFalse(team.peers[1].perform(.returnToLobby))
        XCTAssertTrue(host.perform(.returnToLobby))
        await wait { team.models.allSatisfy { $0.phase == .settings && $0.run == nil } }
        XCTAssertEqual(host.sessionID, session)
        XCTAssertEqual(host.seatStatus.count, 3)
        XCTAssertEqual(team.peers[1].role, .player2)
        XCTAssertEqual(team.peers[2].role, .player3)
        XCTAssertTrue(host.perform(.startRun))
        await wait { team.models.allSatisfy { $0.phase == .playing } }
        team.transports[1].stop()
        await wait { host.paused }
        XCTAssertTrue(host.perform(.returnToLobby), "Host must be able to abandon a paused run")
        await wait { team.models[2].phase == .settings }
        XCTAssertFalse(host.paused)
        XCTAssertEqual(host.sessionID, session)
        XCTAssertFalse(host.canStartRun, "All seats are still required to start")
        await host.leaveSession()
    }

    func testRunSnapshotRoundTripAndInvalidProgressAreRejectedAtomically() async throws {
        let clock = Clock(), team = try await group(clock)
        let snapshot = try XCTUnwrap(team.peers[0].latestSnapshot)
        var codec = LocalMessageCodec()
        let decoded = try codec.append(LocalMessageCodec().encode(.snapshot(snapshot)))
        guard case .snapshot(let copy) = decoded.first else { return XCTFail("Missing run snapshot") }
        XCTAssertEqual(copy.run, snapshot.run)
        XCTAssertEqual(copy.runConfiguration, snapshot.runConfiguration)
        XCTAssertEqual(copy.target?.difficulty, snapshot.target?.difficulty)
        let client = team.models[1], before = client.run, target = client.round?.request.id
        let mapper = LocalGameSnapshotMapper()
        var bad = copy
        bad.run?.day = 0
        XCTAssertThrowsError(try mapper.apply(bad, to: client))
        bad = copy; bad.run?.completed = 101
        XCTAssertThrowsError(try mapper.apply(bad, to: client))
        bad = copy; bad.run?.remainingSeconds = 31
        XCTAssertThrowsError(try mapper.apply(bad, to: client))
        bad = copy; bad.runConfiguration.templates.removeLast()
        XCTAssertThrowsError(try mapper.apply(bad, to: client))
        bad = copy; bad.run?.status = .gameOver
        XCTAssertThrowsError(try mapper.apply(bad, to: client))
        XCTAssertEqual(client.run, before)
        XCTAssertEqual(client.round?.request.id, target)
        await team.peers[0].leaveSession()
    }

    func testBudgetChangesDuringGradingPublishOnlyValidFinalSnapshots() async throws {
        let clock = Clock(), team = try await group(clock)
        clock.readStep = 1
        await grade(team)
        XCTAssertNil(team.peers[0].error, "Clock updates must not publish playing with a cleared majority ballot")
        XCTAssertTrue(team.models.allSatisfy { $0.run?.status == .dayComplete })
        clock.readStep = 0
        await team.peers[0].leaveSession()
    }

    func testVersionTwoSnapshotsAreRejectedBeforeNewFieldsAreDecoded() throws {
        let payload = Data("{\"snapshot\":{\"_0\":{\"protocolVersion\":2}}}".utf8)
        let length = UInt32(payload.count)
        let frame = Data([UInt8(length >> 24), UInt8((length >> 16) & 255), UInt8((length >> 8) & 255), UInt8(length & 255)]) + payload
        var codec = LocalMessageCodec()
        XCTAssertThrowsError(try codec.append(frame)) { XCTAssertEqual($0 as? LocalPlayError, .versionMismatch) }
    }
}
