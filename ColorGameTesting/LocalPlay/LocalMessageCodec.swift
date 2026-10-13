import Foundation

struct LocalMessageCodec {
    private static let maximumPayloadLength = 1_048_576
    private var buffer = Data()

    func encode(_ message: WireMessage) throws -> Data {
        try Self.checkMessage(message)
        let payload = try JSONEncoder().encode(message)
        guard !payload.isEmpty, payload.count <= Self.maximumPayloadLength else {
            throw LocalPlayError.invalidMessage
        }
        let length = UInt32(payload.count)
        return Data([
            UInt8(length >> 24),
            UInt8((length >> 16) & 0xff),
            UInt8((length >> 8) & 0xff),
            UInt8(length & 0xff)
        ]) + payload
    }

    mutating func append(_ data: Data) throws -> [WireMessage] {
        buffer.append(data)
        var messages: [WireMessage] = []
        while buffer.count >= 4 {
            let length = buffer.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            guard length > 0, length <= Self.maximumPayloadLength else {
                throw LocalPlayError.invalidMessage
            }
            guard buffer.count >= 4 + length else { break }
            let payload = Data(buffer.dropFirst(4).prefix(length))
            let message: WireMessage
            do {
                if let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
                   let snapshot = json["snapshot"] as? [String: Any],
                   let fields = snapshot["_0"] as? [String: Any],
                   let version = fields["protocolVersion"] as? Int,
                   version != LocalPlayProtocol.version {
                    throw LocalPlayError.versionMismatch
                }
                message = try JSONDecoder().decode(WireMessage.self, from: payload)
            } catch LocalPlayError.versionMismatch {
                throw LocalPlayError.versionMismatch
            } catch {
                throw LocalPlayError.invalidMessage
            }
            try Self.checkMessage(message)
            messages.append(message)
            buffer.removeFirst(4 + length)
        }
        return messages
    }

    private static func checkMessage(_ message: WireMessage) throws {
        switch message {
        case .snapshot(let snapshot) where snapshot.protocolVersion != LocalPlayProtocol.version:
            throw LocalPlayError.versionMismatch
        case .input(let input):
            switch input.action {
            case .mix, .redo, .finish: throw LocalPlayError.invalidMessage
            default: break
            }
        default:
            break
        }
    }
}
