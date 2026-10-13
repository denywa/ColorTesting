import Foundation

enum ColorHex {
    static func normalized(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard digits.utf8.count == 6, digits.utf8.allSatisfy({ byte in
            (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
        }) else { return nil }
        return "#" + digits.uppercased()
    }

    static func sRGB(_ input: String) -> SIMD3<Double>? {
        guard let normalized = normalized(input),
              let hex = UInt32(normalized.dropFirst(), radix: 16) else { return nil }
        return SIMD3(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    static func string(from sRGB: SIMD3<Double>) -> String {
        let bytes = (0..<3).map { component in
            Int((min(1, max(0, sRGB[component])) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", bytes[0], bytes[1], bytes[2])
    }
}

struct CustomRequestStore {
    private struct Record: Codable {
        let id: UUID
        let text: String
        let hex: String
        let difficulty: Int?
    }

    private static let storageKey = "customColorRequests.v1"
    private static let deletedBuiltInsKey = "deletedBuiltInColorRequests.v1"
    let defaults: UserDefaults

    func loadDeletedBuiltIns() -> Set<UUID> {
        Set((defaults.stringArray(forKey: Self.deletedBuiltInsKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    func saveDeletedBuiltIns(_ ids: Set<UUID>) {
        defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.deletedBuiltInsKey)
    }

    func load() -> [ColorRequest] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let records = try? JSONDecoder().decode([Record].self, from: data) else { return [] }
        return records.compactMap { record in
            guard !record.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let color = ColorHex.sRGB(record.hex),
                  let difficulty = RequestDifficulty(rawValue: record.difficulty ?? 1) else { return nil }
            return ColorRequest(id: record.id, text: record.text, targetSRGB: color, difficulty: difficulty)
        }
    }

    func save(_ requests: [ColorRequest]) -> Bool {
        let records = requests.map {
            Record(id: $0.id, text: $0.text, hex: ColorHex.string(from: $0.targetSRGB),
                   difficulty: $0.difficulty.rawValue)
        }
        guard let data = try? JSONEncoder().encode(records) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        return true
    }
}
