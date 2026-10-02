import Foundation

struct ColorRequest: Identifiable {
    let id: UUID
    let text: String
    let targetSRGB: SIMD3<Double>
}

enum ColorData {
    static let cmykPalette: [NamedColor] = [
        NamedColor(id: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
                   name: "Cyan", sRGB: SIMD3(0, 1, 1),
                   cmykComponents: SIMD4(1, 0, 0, 0), rybComponents: nil),
        NamedColor(id: UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!,
                   name: "Magenta", sRGB: SIMD3(1, 0, 1),
                   cmykComponents: SIMD4(0, 1, 0, 0), rybComponents: nil),
        NamedColor(id: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
                   name: "Yellow", sRGB: SIMD3(1, 1, 0),
                   cmykComponents: SIMD4(0, 0, 1, 0), rybComponents: nil),
        NamedColor(id: UUID(uuidString: "A0000000-0000-0000-0000-000000000004")!,
                   name: "Black", sRGB: SIMD3(0, 0, 0),
                   cmykComponents: SIMD4(0, 0, 0, 1), rybComponents: nil),
        NamedColor(id: UUID(uuidString: "A0000000-0000-0000-0000-000000000005")!,
                   name: "White", sRGB: SIMD3(1, 1, 1),
                   cmykComponents: SIMD4(0, 0, 0, 0), rybComponents: nil)
    ]

    static let rybPalette: [NamedColor] = [
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000001")!,
                   name: "Red", sRGB: SIMD3(1, 0, 0),
                   cmykComponents: nil, rybComponents: SIMD3(1, 0, 0)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
                   name: "Yellow", sRGB: SIMD3(1, 1, 0),
                   cmykComponents: nil, rybComponents: SIMD3(0, 1, 0)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000003")!,
                   name: "Blue", sRGB: SIMD3(0, 0, 1),
                   cmykComponents: nil, rybComponents: SIMD3(0, 0, 1)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000004")!,
                   name: "Black", sRGB: SIMD3(0, 0, 0),
                   cmykComponents: nil, rybComponents: SIMD3(0, 0, 0)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000005")!,
                   name: "White", sRGB: SIMD3(1, 1, 1),
                   cmykComponents: nil, rybComponents: SIMD3(0.5, 0.5, 0.5))
    ]

    static let requestPool: [ColorRequest] = [
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000001")!,
                     text: "Matcha latte, but sadder", targetSRGB: SIMD3(0.42, 0.58, 0.35)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000002")!,
                     text: "A sunset that feels embarrassed", targetSRGB: SIMD3(0.96, 0.51, 0.32)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000003")!,
                     text: "The last sip of blueberry tea", targetSRGB: SIMD3(0.37, 0.28, 0.57)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000004")!,
                     text: "Moss after a summer storm", targetSRGB: SIMD3(0.31, 0.45, 0.24)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000005")!,
                     text: "A flamingo's day off", targetSRGB: SIMD3(0.91, 0.57, 0.65)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000006")!,
                     text: "Moonlight on a frozen pond", targetSRGB: SIMD3(0.61, 0.77, 0.84)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000007")!,
                     text: "A dusty library curtain", targetSRGB: SIMD3(0.62, 0.51, 0.43)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000008")!,
                     text: "The inside of a ripe peach", targetSRGB: SIMD3(0.98, 0.68, 0.47)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-000000000009")!,
                     text: "A deep sea secret", targetSRGB: SIMD3(0.12, 0.32, 0.42)),
        ColorRequest(id: UUID(uuidString: "C0000000-0000-0000-0000-00000000000A")!,
                     text: "Lavender at the end of winter", targetSRGB: SIMD3(0.72, 0.65, 0.82))
    ]

    static func colors(for model: ColorModel) -> [NamedColor] {
        switch model {
        case .cmyk: return cmykPalette
        case .ryb: return rybPalette
        }
    }
}
