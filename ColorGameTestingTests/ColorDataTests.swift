import Foundation
import XCTest
@testable import ColorGameTesting

final class ColorDataTests: XCTestCase {
    func testCMYKPaletteMatchesDesignTable() {
        let expected: [(String, SIMD4<Double>, SIMD3<Double>)] = [
            ("Cyan", SIMD4(1, 0, 0, 0), SIMD3(0, 1, 1)),
            ("Magenta", SIMD4(0, 1, 0, 0), SIMD3(1, 0, 1)),
            ("Yellow", SIMD4(0, 0, 1, 0), SIMD3(1, 1, 0)),
            ("Black", SIMD4(0, 0, 0, 1), SIMD3(0, 0, 0)),
            ("White", SIMD4(0, 0, 0, 0), SIMD3(1, 1, 1))
        ]

        XCTAssertEqual(ColorData.cmykPalette.count, expected.count)
        for (name, components, srgb) in expected {
            guard let color = ColorData.cmykPalette.first(where: { $0.name == name }) else {
                XCTFail("Missing CMYK color \(name)")
                continue
            }
            XCTAssertEqual(color.cmykComponents, components)
            XCTAssertEqual(color.sRGB, srgb)
            XCTAssertNil(color.rybComponents)
        }
        XCTAssertEqual(Set(ColorData.cmykPalette.map(\.name)).count, expected.count)
        XCTAssertEqual(Set(ColorData.cmykPalette.map(\.id)).count, expected.count)
    }

    func testRYBPaletteMatchesDesignTable() {
        let expected: [(String, SIMD3<Double>, SIMD3<Double>)] = [
            ("Red", SIMD3(1, 0, 0), SIMD3(1, 0, 0)),
            ("Yellow", SIMD3(0, 1, 0), SIMD3(1, 1, 0)),
            ("Blue", SIMD3(0, 0, 1), SIMD3(0, 0, 1)),
            ("Black", SIMD3(0, 0, 0), SIMD3(0, 0, 0)),
            ("White", SIMD3(0.5, 0.5, 0.5), SIMD3(1, 1, 1))
        ]

        XCTAssertEqual(ColorData.rybPalette.count, expected.count)
        for (name, components, srgb) in expected {
            guard let color = ColorData.rybPalette.first(where: { $0.name == name }) else {
                XCTFail("Missing RYB color \(name)")
                continue
            }
            XCTAssertEqual(color.rybComponents, components)
            XCTAssertEqual(color.sRGB, srgb)
            XCTAssertNil(color.cmykComponents)
        }
        XCTAssertEqual(Set(ColorData.rybPalette.map(\.name)).count, expected.count)
        XCTAssertEqual(Set(ColorData.rybPalette.map(\.id)).count, expected.count)
    }

    func testColorsHelperSelectsOnlyTheRequestedModel() {
        XCTAssertEqual(ColorData.colors(for: .cmyk), ColorData.cmykPalette)
        XCTAssertEqual(ColorData.colors(for: .ryb), ColorData.rybPalette)
        XCTAssertTrue(Set(ColorData.cmykPalette.map(\.id)).isDisjoint(with: Set(ColorData.rybPalette.map(\.id))))
    }

    func testRequestPoolMatchesSuppliedNamesAndHexTargets() {
        let requests = ColorData.requestPool
        let expected: [(String, SIMD3<Double>)] = [
            ("glossy mocha brown", SIMD3(74.0 / 255, 59.0 / 255, 50.0 / 255)),
            ("milk tea", SIMD3(200.0 / 255, 177.0 / 255, 154.0 / 255)),
            ("honey blonde", SIMD3(246.0 / 255, 212.0 / 255, 139.0 / 255)),
            ("lavender", SIMD3(200.0 / 255, 180.0 / 255, 244.0 / 255)),
            ("sky blue", SIMD3(135.0 / 255, 206.0 / 255, 250.0 / 255)),
            ("red blood", SIMD3(178.0 / 255, 34.0 / 255, 34.0 / 255)),
            ("juicy orange", SIMD3(255.0 / 255, 140.0 / 255, 50.0 / 255))
        ]
        XCTAssertEqual(requests.count, expected.count)
        XCTAssertEqual(Set(requests.map(\.text)).count, requests.count)
        XCTAssertEqual(Set(requests.map(\.id)).count, requests.count)
        XCTAssertTrue(requests.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(requests.allSatisfy { request in
            (0..<3).allSatisfy { (0.0...1.0).contains(request.targetSRGB[$0]) }
        })
        let expectedIDs = (1...7).map {
            UUID(uuidString: String(format: "C0000000-0000-0000-0000-%012X", $0))!
        }
        XCTAssertEqual(requests.map(\.id), expectedIDs)
        XCTAssertEqual(requests.map(\.text), expected.map(\.0))
        for (request, (_, target)) in zip(requests, expected) {
            XCTAssertEqual(request.targetSRGB, target, "Wrong target for \(request.text)")
        }
    }

    func testColorRequestStoresItsIdentityTextAndTarget() {
        let id = UUID(uuidString: "D0000000-0000-0000-0000-000000000001")!
        let request = ColorRequest(id: id, text: "Test color", targetSRGB: SIMD3(0.1, 0.2, 0.3))
        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.text, "Test color")
        XCTAssertEqual(request.targetSRGB, SIMD3(0.1, 0.2, 0.3))
    }
}
