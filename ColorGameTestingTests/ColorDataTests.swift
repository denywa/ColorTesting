import Foundation
import XCTest
@testable import ColorGameTesting

final class ColorDataTests: XCTestCase {
    func testRYBPaletteMatchesDesignTable() {
        let expected: [(String, SIMD3<Double>, SIMD3<Double>)] = [
            ("Red", SIMD3(1, 0, 0), SIMD3(1, 0, 0)),
            ("Yellow", SIMD3(0, 1, 0), SIMD3(1, 1, 0)),
            ("Blue", SIMD3(0, 0, 1), SIMD3(0, 0, 1)),
            ("Black", SIMD3(1, 1, 1), SIMD3(0, 0, 0)),
            ("White", SIMD3(0, 0, 0), SIMD3(1, 1, 1))
        ]

        XCTAssertEqual(ColorData.rybPalette.count, expected.count)
        for (name, components, srgb) in expected {
            guard let color = ColorData.rybPalette.first(where: { $0.name == name }) else {
                XCTFail("Missing RYB color \(name)")
                continue
            }
            XCTAssertEqual(color.rybComponents, components)
            XCTAssertEqual(color.sRGB, srgb)
        }
        XCTAssertEqual(Set(ColorData.rybPalette.map(\.name)).count, expected.count)
        XCTAssertEqual(Set(ColorData.rybPalette.map(\.id)).count, expected.count)
        XCTAssertEqual(ColorData.rybPalette.map(\.id), (1...5).map {
            UUID(uuidString: String(format: "B0000000-0000-0000-0000-%012X", $0))!
        })
        XCTAssertTrue(ColorData.rybPalette.allSatisfy { color in
            (0..<3).allSatisfy { (0...1).contains(color.rybComponents[$0]) }
        })
    }

    func testColorsHelperSelectsOnlyTheRequestedModel() {
        XCTAssertEqual(ColorData.colors(for: .ryb), ColorData.rybPalette)
    }

    func testRequestPoolContainsOnlyTheNewLevelCatalogs() {
        let requests = ColorData.requestPool
        XCTAssertEqual(requests.count, 103)
        XCTAssertFalse(requests.contains { $0.id.uuidString.hasPrefix("C0000000-") })
        XCTAssertEqual(Set(requests.map(\.text)).count, requests.count)
        XCTAssertEqual(Set(requests.map(\.id)).count, requests.count)
        XCTAssertTrue(requests.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(requests.allSatisfy { request in
            (0..<3).allSatisfy { (0.0...1.0).contains(request.targetSRGB[$0]) }
        })
    }

    func testColorRequestStoresItsIdentityTextAndTarget() {
        let id = UUID(uuidString: "D0000000-0000-0000-0000-000000000001")!
        let request = ColorRequest(id: id, text: "Test color", targetSRGB: SIMD3(0.1, 0.2, 0.3))
        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.text, "Test color")
        XCTAssertEqual(request.targetSRGB, SIMD3(0.1, 0.2, 0.3))
    }

    func testLevel2RequestsMatchApprovedCopyAndTargets() {
        let expected: [(String, String)] = [
            ("Give me the color of tropical water around a sunny island. Well, I deserve a private beach.", "#40E0D0"),
            ("I want the color on a teal duck's head. Nature clearly designed it for someone as fabulous as me.", "#008080"),
            ("Give me the color of the sea far below the surface, where sunlight barely reaches. Mysterious, just like my beauty!", "#005B96"),
            ("I want the bold blue associated with royal robes and grand ceremonies. Make me look ready to take the throne!", "#4169E1"),
            ("Honey, give me the color of the ink inside a classic blue ballpoint pen. You know, the one you borrow and NEVER return!", "#1A43BF"),
            ("I want the color of the fruit people slice for burgers and salads. Round, juicy, and obviously iconic!", "#FF6347"),
            ("Give me the color of traditional clay bricks used to build house walls. Not painted bricks, darling. The classic ones straight from the construction site!", "#B55239"),
            ("I want the color that appears on iron left outside in the rain for too long. Even old metal has style!", "#B7410E"),
            ("Darling, I want the classic rose from a romantic date. The one with velvety petals that people give when they say ‘I love you.’ A whole bouquet of them, please!", "#C21E56"),
            ("Give me the color of a fully ripe chili pepper. The spicy little diva that turns your favorite sambal into a fiery masterpiece!", "#D62828"),
            ("Give me the color of the sweet liquid made by bees and stored in a jar. Nature's luxury product!", "#DDAF26"),
            ("I want the color of a ripe fruit monkeys love. Not green, not brown. The perfect snack!", "#FFE135"),
            ("Give me the color of the inside of a freshly baked sponge cake. That sunny, fluffy center that makes every tea party fabulous!", "#F4D35E"),
            ("Sweetheart, give me the golden color of a shiny gold coin. Rich, bright, and expensive-looking. Naturally, just like me!", "#FFC000"),
            ("Give me the soft, creamy color of vanilla pudding. Smooth, sweet, and delicate enough for my royal taste!", "#F3E5AB"),
            ("I want the color of the soft growth that covers damp stones and tree trunks. Woodland chic, darling!", "#8A9A5B"),
            ("I want the color of the polished green stone used to make bracelets and carved ornaments. Ancient treasure, modern diva!", "#00A86B"),
            ("Give me the dark green associated with traditional outdoor jackets and forest clothing. Rugged, but still runway-ready!", "#355E3B"),
            ("Make it like my matcha latte order. Extra fancy, perfectly whisked, and absolutely NOT the cheap stuff!", "#A8B876"),
            ("One scoop of mint ice cream, please! Cool, creamy, and expensive-looking. Unlike my last situationship.", "#B7E4C7"),
            ("Give me the color of the big round fruit people carve into spooky faces for Halloween. Scary? Only my beauty!", "#FF7518"),
            ("I want the brown powder people use to make chocolate desserts. Sweetness is optional, darling!", "#6F4E37"),
            ("Give me the color inspired by a drink made with coffee and chocolate together. Two classics, one flawless customer!", "#967969")
        ]
        let requests = ColorData.requestPool.filter {
            $0.id.uuidString.hasPrefix("C2000000-")
        }
        XCTAssertEqual(requests.count, expected.count)
        for (index, fixture) in expected.enumerated() {
            let request = requests[index]
            XCTAssertEqual(request.id, UUID(uuidString: String(format: "C2000000-0000-0000-0000-%012X", index + 1)))
            XCTAssertEqual(request.text, fixture.0)
            XCTAssertEqual(ColorHex.string(from: request.targetSRGB), fixture.1)
            XCTAssertEqual(request.difficulty, .level2)
        }
    }
}
