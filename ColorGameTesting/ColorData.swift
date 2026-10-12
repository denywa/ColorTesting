import Foundation

struct ColorRequest: Identifiable {
    let id: UUID
    let text: String
    let targetSRGB: SIMD3<Double>
}

enum ColorData {
    static let rybPalette: [NamedColor] = [
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000001")!,
                   name: "Red", sRGB: SIMD3(1, 0, 0),
                   rybComponents: SIMD3(1, 0, 0)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
                   name: "Yellow", sRGB: SIMD3(1, 1, 0),
                   rybComponents: SIMD3(0, 1, 0)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000003")!,
                   name: "Blue", sRGB: SIMD3(0, 0, 1),
                   rybComponents: SIMD3(0, 0, 1)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000004")!,
                   name: "Black", sRGB: SIMD3(0, 0, 0),
                   rybComponents: SIMD3(1, 1, 1)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000005")!,
                   name: "White", sRGB: SIMD3(1, 1, 1),
                   rybComponents: SIMD3(0, 0, 0))
    ]

    static let requestPool: [ColorRequest] = [
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000001")!,
                     text: "Glossy mocha brown", targetSRGB: sRGB(hex: 0x4A3B32)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000002")!,
                     text: "Milk tea", targetSRGB: sRGB(hex: 0xC8B19A)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000003")!,
                     text: "Honey blonde", targetSRGB: sRGB(hex: 0xF6D48B)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000004")!,
                     text: "Lavender", targetSRGB: sRGB(hex: 0xC8B4F4)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000005")!,
                     text: "Sky blue", targetSRGB: sRGB(hex: 0x87CEFA)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000006")!,
                     text: "Red blood", targetSRGB: sRGB(hex: 0xB22222)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000007")!,
                     text: "Juicy orange", targetSRGB: sRGB(hex: 0xFF8C32))
    ]

    private static func sRGB(hex: UInt32) -> SIMD3<Double> {
        SIMD3(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    static func colors(for model: ColorModel) -> [NamedColor] {
        switch model {
        case .ryb: return rybPalette
        }
    }
}
