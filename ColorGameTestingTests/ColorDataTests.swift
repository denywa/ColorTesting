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

    func testRequestPoolHasUniqueStableIDsAndUsableTargets() {
        let requests = ColorData.requestPool
        XCTAssertGreaterThanOrEqual(requests.count, 10)
        XCTAssertEqual(Set(requests.map(\.text)).count, requests.count)
        XCTAssertEqual(Set(requests.map(\.id)).count, requests.count)
        XCTAssertTrue(requests.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(requests.allSatisfy { request in
            (0..<3).allSatisfy { (0.0...1.0).contains(request.targetSRGB[$0]) }
        })
        let expectedIDs = (1...10).map {
            UUID(uuidString: String(format: "C0000000-0000-0000-0000-%012X", $0))!
        }
        XCTAssertEqual(requests.map(\.id), expectedIDs)
        XCTAssertEqual(requests.first?.text, "Matcha latte, but sadder")
        XCTAssertEqual(requests.first?.targetSRGB, SIMD3(0.42, 0.58, 0.35))
    }

    func testColorRequestStoresItsIdentityTextAndTarget() {
        let id = UUID(uuidString: "D0000000-0000-0000-0000-000000000001")!
        let request = ColorRequest(id: id, text: "Test color", targetSRGB: SIMD3(0.1, 0.2, 0.3))
        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.text, "Test color")
        XCTAssertEqual(request.targetSRGB, SIMD3(0.1, 0.2, 0.3))
    }
}
