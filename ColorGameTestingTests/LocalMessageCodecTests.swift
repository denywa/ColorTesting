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
        let snapshot = GameSnapshot(protocolVersion: LocalPlayProtocol.version, sessionID: sessionID, snapshotRevision: 1, phase: .settings, roundID: nil, selectedModel: nil, target: .init(id: UUID(), text: String(repeating: "x", count: 1_048_576), sRGB: .init(red: 0, green: 0, blue: 0)), reassignmentDuration: 8, showTargetColor: false, timerSecondsRemaining: 8, assignmentEpoch: nil, assignments: [], mixEntries: [], mixLocked: false, mixResult: nil, score: nil, paused: false, seatStatus: [])
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
        let snapshot = GameSnapshot(protocolVersion: LocalPlayProtocol.version + 1, sessionID: sessionID, snapshotRevision: 1, phase: .settings, roundID: nil, selectedModel: nil, target: nil, reassignmentDuration: 8, showTargetColor: false, timerSecondsRemaining: 8, assignmentEpoch: nil, assignments: [], mixEntries: [], mixLocked: false, mixResult: nil, score: nil, paused: false, seatStatus: [])
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

    private func frame(_ payload: Data) -> Data {
        let length = UInt32(payload.count)
        return Data([UInt8(length >> 24), UInt8((length >> 16) & 0xff), UInt8((length >> 8) & 0xff), UInt8(length & 0xff)]) + payload
    }
}
