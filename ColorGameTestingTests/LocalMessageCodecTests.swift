import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor final class LocalMessageCodecTests: XCTestCase {
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var message: WireMessage {
        .hello(.init(protocolVersion: LocalPlayProtocol.version, clientID: UUID(), sessionID: sessionID, reconnectToken: nil))
    }

    func testIntactMessageUsesNetworkOrderLengthAndRoundTrips() throws {
        let codec = LocalMessageCodec()
        let original = message
        let frame = try codec.encode(original)
        let payload = try JSONEncoder().encode(original)
        XCTAssertEqual(Array(frame.prefix(4)), [0, 0, UInt8(payload.count >> 8), UInt8(payload.count & 0xff)])
        var decoder = LocalMessageCodec()
        let decoded = try decoder.append(frame)
        XCTAssertEqual(decoded.count, 1)
        if case .hello(let hello) = decoded[0], case .hello(let expected) = original {
            XCTAssertEqual(hello.clientID, expected.clientID)
            XCTAssertEqual(hello.sessionID, expected.sessionID)
        } else {
            XCTFail("Expected original Hello")
        }
    }

    func testSplitPrefixAndPayloadWaitForCompleteFrame() throws {
        let frame = try LocalMessageCodec().encode(message)
        var decoder = LocalMessageCodec()
        XCTAssertTrue(try decoder.append(frame.prefix(2)).isEmpty)
        XCTAssertTrue(try decoder.append(frame.dropFirst(2).prefix(3)).isEmpty)
        XCTAssertEqual(try decoder.append(frame.dropFirst(5)).count, 1)
    }

    func testCoalescedFramesAreReturnedInOrder() throws {
        let codec = LocalMessageCodec()
        let first = try codec.encode(.heartbeat(.init(sessionID: sessionID, ping: 1)))
        let second = try codec.encode(.heartbeat(.init(sessionID: sessionID, ping: 2)))
        var decoder = LocalMessageCodec()
        let messages = try decoder.append(first + second)
        XCTAssertEqual(messages.count, 2)
        if case .heartbeat(let heartbeat) = messages[0] { XCTAssertEqual(heartbeat.ping, 1) } else { XCTFail("Expected first heartbeat") }
        if case .heartbeat(let heartbeat) = messages[1] { XCTAssertEqual(heartbeat.ping, 2) } else { XCTFail("Expected second heartbeat") }
    }

    func testMalformedJSONIsRejected() throws {
        var decoder = LocalMessageCodec()
        XCTAssertThrowsError(try decoder.append(frame(Data("not json".utf8)))) { error in
            XCTAssertEqual(error as? LocalPlayError, .invalidMessage)
        }
    }

    func testOversizedLengthIsRejectedBeforePayloadArrives() throws {
        var decoder = LocalMessageCodec()
        XCTAssertThrowsError(try decoder.append(Data([0, 16, 0, 1]))) { error in
            XCTAssertEqual(error as? LocalPlayError, .invalidMessage)
        }
    }

    func testOversizedEncodedPayloadIsRejected() throws {
        let snapshot = GameSnapshot(protocolVersion: LocalPlayProtocol.version, sessionID: sessionID, snapshotRevision: 1, phase: .settings, roundID: nil, selectedModel: nil, mixMode: .manual, target: .init(id: UUID(), text: String(repeating: "x", count: 1_048_576), sRGB: .init(red: 0, green: 0, blue: 0)), reassignmentDuration: 8, showTargetColor: false, timerSecondsRemaining: 8, assignmentEpoch: nil, assignments: [], mixEntries: [], mixLocked: false, mixResult: nil, currentBlend: nil, voting: nil, score: nil, paused: false, seatStatus: [])
        XCTAssertThrowsError(try LocalMessageCodec().encode(.snapshot(snapshot))) { error in
            XCTAssertEqual(error as? LocalPlayError, .invalidMessage)
        }
    }

    func testMismatchedHelloVersionReachesCoordinatorForRejection() throws {
        let wrong = WireMessage.hello(.init(protocolVersion: LocalPlayProtocol.version + 1, clientID: UUID(), sessionID: nil, reconnectToken: nil))
        var decoder = LocalMessageCodec()
        let messages = try decoder.append(frame(JSONEncoder().encode(wrong)))
        guard case .hello(let decoded) = messages.first else { return XCTFail("Expected Hello") }
        XCTAssertEqual(decoded.protocolVersion, LocalPlayProtocol.version + 1)
    }

    func testMismatchedSnapshotVersionIsRejected() throws {
        let snapshot = GameSnapshot(protocolVersion: LocalPlayProtocol.version + 1, sessionID: sessionID, snapshotRevision: 1, phase: .settings, roundID: nil, selectedModel: nil, mixMode: .manual, target: nil, reassignmentDuration: 8, showTargetColor: false, timerSecondsRemaining: 8, assignmentEpoch: nil, assignments: [], mixEntries: [], mixLocked: false, mixResult: nil, currentBlend: nil, voting: nil, score: nil, paused: false, seatStatus: [])
        var decoder = LocalMessageCodec()
        XCTAssertThrowsError(try decoder.append(frame(JSONEncoder().encode(WireMessage.snapshot(snapshot))))) { error in
            XCTAssertEqual(error as? LocalPlayError, .versionMismatch)
        }
    }

    func testDecoderBuffersAreIndependent() throws {
        let frame = try LocalMessageCodec().encode(message)
        var first = LocalMessageCodec()
        var second = LocalMessageCodec()
        XCTAssertTrue(try first.append(frame.prefix(3)).isEmpty)
        XCTAssertEqual(try second.append(frame).count, 1)
        XCTAssertEqual(try first.append(frame.dropFirst(3)).count, 1)
    }

    func testVersionThreeContractAndVotePayload() throws {
        XCTAssertEqual(LocalPlayProtocol.version, 4)
        let ballot = UUID()
        let input = Data("""
        {"input":{"_0":{"sessionID":"\(sessionID)","roundID":"\(UUID())","actionID":"\(UUID())","action":{"vote":{"action":"apply","votingID":"\(ballot)"}}}}}
        """.utf8)
        var decoder = LocalMessageCodec()
        XCTAssertEqual(try decoder.append(frame(input)).count, 1)
    }

    func testLegacyPhaseActionsAreRejectedOnWire() throws {
        for action in ["mix", "finish", "redo"] {
            let payload = Data("""
            {"input":{"_0":{"sessionID":"\(sessionID)","roundID":"\(UUID())","actionID":"\(UUID())","action":{"\(action)":{}}}}}
            """.utf8)
            var decoder = LocalMessageCodec()
            XCTAssertThrowsError(try decoder.append(frame(payload)))
        }
    }

    func testSnapshotModesAndPhasesRoundTripInPartialAndCombinedFrames() throws {
        let codec = LocalMessageCodec()
        var frames = Data()
        let ballot = UUID()
        for mode in MixMode.allCases {
            for phase: GamePhase in [.settings, .playing, .result, .score] {
                let active = phase != .settings
                let live = active && mode == .auto && phase == .playing
                let voting: LocalVotingState? = phase == .playing || phase == .result
                    ? .init(id: ballot, votes: [.init(player: .player1, action: mode == .auto ? .apply : .mix),
                                               .init(player: .player3, action: .redo)]) : nil
                let snapshot = GameSnapshot(protocolVersion: LocalPlayProtocol.version, sessionID: sessionID, snapshotRevision: 3,
                    phase: phase, roundID: active ? UUID() : nil, selectedModel: .ryb, mixMode: mode,
                    target: active ? .init(id: UUID(), text: "Target", sRGB: .init(red: 0.1, green: 0.2, blue: 0.3)) : nil,
                    reassignmentDuration: 8, showTargetColor: true, timerSecondsRemaining: 4,
                    assignmentEpoch: active ? 2 : nil, assignments: [], mixEntries: [],
                    mixLocked: phase == .result || phase == .score,
                    mixResult: phase == .result || phase == .score ? .init(red: 0.4, green: 0.5, blue: 0.6) : nil,
                    currentBlend: live ? .init(red: 0.7, green: 0.8, blue: 0.9) : nil,
                    voting: voting, score: phase == .score ? 80 : nil, paused: false, seatStatus: [])
                frames += try codec.encode(.snapshot(snapshot))
            }
        }
        var decoder = LocalMessageCodec()
        XCTAssertTrue(try decoder.append(frames.prefix(3)).isEmpty)
        XCTAssertTrue(try decoder.append(frames.dropFirst(3).prefix(5)).isEmpty)
        let messages = try decoder.append(frames.dropFirst(8))
        XCTAssertEqual(messages.count, 8)
        for (index, message) in messages.enumerated() {
            guard case .snapshot(let snapshot) = message else { return XCTFail("Expected snapshot") }
            XCTAssertEqual(snapshot.mixMode, index < 4 ? .manual : .auto)
            XCTAssertEqual(snapshot.voting?.id, index % 4 == 1 || index % 4 == 2 ? ballot : nil)
            XCTAssertEqual(snapshot.voting?.votes.map(\.player), index % 4 == 1 || index % 4 == 2 ? [.player1, .player3] : nil)
            XCTAssertEqual(snapshot.currentBlend?.blue, index == 5 ? 0.9 : nil)
        }
    }

    func testVoteFramesCanBeSplitAndCombined() throws {
        let ballot = UUID()
        let codec = LocalMessageCodec()
        let first = try codec.encode(.input(.init(sessionID: sessionID, roundID: UUID(), actionID: UUID(),
                                                action: .vote(action: .apply, votingID: ballot))))
        let second = try codec.encode(.input(.init(sessionID: sessionID, roundID: UUID(), actionID: UUID(),
                                                 action: .vote(action: .redo, votingID: ballot))))
        var decoder = LocalMessageCodec()
        XCTAssertTrue(try decoder.append(first.prefix(2)).isEmpty)
        XCTAssertTrue(try decoder.append(first.dropFirst(2).prefix(10)).isEmpty)
        let messages = try decoder.append(first.dropFirst(12) + second)
        XCTAssertEqual(messages.count, 2)
        for (message, expected) in zip(messages, [LocalVoteAction.apply, .redo]) {
            guard case .input(let input) = message,
                  case .vote(let action, let votingID) = input.action else { return XCTFail("Expected vote") }
            XCTAssertEqual(action, expected)
            XCTAssertEqual(votingID, ballot)
        }
    }

    func testVersionOneHelloAndRejectPreserveOriginalJSONShapes() throws {
        let hello = Data("""
        {"hello":{"_0":{"protocolVersion":1,"clientID":"\(sessionID)"}}}
        """.utf8)
        let rejection = Data("""
        {"reject":{"_0":{"sessionID":"\(sessionID)","reason":"versionMismatch"}}}
        """.utf8)
        var decoder = LocalMessageCodec()
        let messages = try decoder.append(frame(hello) + frame(rejection))
        for (message, original) in zip(messages, [hello, rejection]) {
            let actual = try LocalMessageCodec().encode(message).dropFirst(4)
            XCTAssertEqual(try JSONSerialization.jsonObject(with: Data(actual)) as? NSDictionary,
                           try JSONSerialization.jsonObject(with: original) as? NSDictionary)
        }
    }

    func testVersionOneSnapshotWithoutNewFieldsIsRejectedBeforeDecoding() throws {
        let payload = Data("""
        {"snapshot":{"_0":{"protocolVersion":1}}}
        """.utf8)
        var decoder = LocalMessageCodec()
        XCTAssertThrowsError(try decoder.append(frame(payload))) {
            XCTAssertEqual($0 as? LocalPlayError, .versionMismatch)
        }
    }

    private func frame(_ payload: Data) -> Data {
        let length = UInt32(payload.count)
        return Data([UInt8(length >> 24), UInt8((length >> 16) & 0xff), UInt8((length >> 8) & 0xff), UInt8(length & 0xff)]) + payload
    }
}
