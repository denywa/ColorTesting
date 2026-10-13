import Foundation
import XCTest
@testable import ColorGameTesting

final class ColorMixerTests: XCTestCase {
    func testRandomSingleColorIsIdentityForAnyPositiveUnitCount() {
        let seed: UInt64 = 0xC010_0015
        var generator = MixerSeededGenerator(seed: seed)

        for iteration in 0..<200 {
            let model: ColorModel = .ryb
            let color = randomColor(idNumber: iteration + 1, using: &generator)
            let count = Int.random(in: 1...100, using: &generator)
            let units = Array(repeating: ColorUnit(color: color), count: count)

            XCTAssertEqual(
                ColorMixer.blend(units, model: model), color.sRGB,
                "seed=\(seed), iteration=\(iteration), model=\(model), count=\(count), id=\(color.id), sRGB=\(color.sRGB), ryb=\(String(describing: color.rybComponents))"
            )
        }
    }


    func testRYBPaletteMatchesDiagramOverlaps() {
        let palette = ColorData.rybPalette
        let cases: [([Int], SIMD3<Double>)] = [
            ([0, 1], SIMD3(243, 177, 61) / 255),
            ([0, 2], SIMD3(171, 41, 220) / 255),
            ([1, 2], SIMD3(96, 200, 60) / 255),
            ([0, 1, 2], SIMD3(74, 74, 74) / 255)
        ]
        for (indices, expected) in cases {
            let units = indices.map { ColorUnit(color: palette[$0]) }
            assertRGB(ColorMixer.blend(units, model: .ryb), equals: expected)
        }
    }

    func testRYBSeparatesThreePrimariesFromBlackAndWhite() {
        let palette = ColorData.rybPalette
        let threePrimaries = [0, 1, 2].map { ColorUnit(color: palette[$0]) }
        let dilutedBlack = [3, 4, 4].map { ColorUnit(color: palette[$0]) }
        XCTAssertNotEqual(ColorMixer.blend(threePrimaries, model: .ryb),
                          ColorMixer.blend(dilutedBlack, model: .ryb))
        assertRGB(ColorMixer.blend(dilutedBlack, model: .ryb),
                  equals: SIMD3(repeating: 2.0 / 3.0))
        assertRGB(ColorMixer.blend([ColorUnit(color: palette[0]), ColorUnit(color: palette[3])], model: .ryb),
                  equals: SIMD3(0.5, 0, 0))
        assertRGB(ColorMixer.blend([ColorUnit(color: palette[0]), ColorUnit(color: palette[4])], model: .ryb),
                  equals: SIMD3(1, 0.5, 0.5))
    }

    func testRYBAdditionalUnitChangesBlendRegardlessOfOrder() {
        let red = ColorUnit(color: ColorData.rybPalette[0])
        let yellow = ColorUnit(color: ColorData.rybPalette[1])
        let balanced = ColorMixer.blend([red, yellow], model: .ryb)
        let redHeavy = ColorMixer.blend([red, red, yellow], model: .ryb)
        XCTAssertLessThan(redHeavy.y, balanced.y)
        XCTAssertGreaterThan(redHeavy.x, balanced.x)
        XCTAssertEqual(redHeavy, ColorMixer.blend([yellow, red, red], model: .ryb))
    }

    func testSingleDistinctColorReturnsItsStoredSRGBExactly() {
        for model in ColorModel.allCases {
            for color in ColorData.colors(for: model) {
                for count in [1, 3] {
                    let units = Array(repeating: ColorUnit(color: color), count: count)
                    XCTAssertEqual(ColorMixer.blend(units, model: model), color.sRGB)
                }
            }
        }
    }

    func testCompleteAcceptedUnitsPreserveWeightAndNeutralDilution() {
        let palette = ColorData.rybPalette
        let units = [0, 1, 0, 3, 4].map { ColorUnit(color: palette[$0]) }
        let primary = palette[0].sRGB / 3 + SIMD3(243, 177, 61) / 255 * (2.0 / 3)
        let expected = primary * (3.0 / 5) + SIMD3(repeating: 1.0 / 5)
        assertRGB(ColorMixer.blend(units, model: .ryb), equals: expected)
        XCTAssertNotEqual(ColorMixer.blend(units, model: .ryb), units.last!.color.sRGB)
        assertRGB(ColorMixer.blend(units + units, model: .ryb), equals: expected)
        assertRGB(ColorMixer.blend(Array(units.reversed()), model: .ryb), equals: expected)

        let mostlyRed = Array(repeating: ColorUnit(color: palette[0]), count: 99)
            + [ColorUnit(color: palette[3])]
        assertRGB(ColorMixer.blend(mostlyRed, model: .ryb), equals: SIMD3(0.99, 0, 0))
    }

    func testCalculatedRYBChannelsAreClamped() {
        let components = SIMD3<Double>(-1, 2, 0)
        let colors = (0..<2).map { _ in
            NamedColor(id: UUID(), name: "Out of range", sRGB: SIMD3(0, 0, 0),
                       rybComponents: components)
        }
        assertRGB(ColorMixer.blend(colors.map { ColorUnit(color: $0) }, model: .ryb),
                  equals: SIMD3(1, 1, 0))
    }

    private func randomColor(
        idNumber: Int, using generator: inout MixerSeededGenerator
    ) -> NamedColor {
        let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", idNumber))!
        let srgb = SIMD3(
            Double.random(in: 0...1, using: &generator),
            Double.random(in: 0...1, using: &generator),
            Double.random(in: 0...1, using: &generator)
        )
        return NamedColor(
            id: id, name: "Generated RYB", sRGB: srgb,
            rybComponents: SIMD3(
                Double.random(in: 0...1, using: &generator),
                Double.random(in: 0...1, using: &generator),
                Double.random(in: 0...1, using: &generator)
            )
        )
    }

    private func assertRGB(_ actual: SIMD3<Double>, equals expected: SIMD3<Double>,
                           file: StaticString = #filePath, line: UInt = #line) {
        for channel in 0..<3 {
            XCTAssertEqual(actual[channel], expected[channel], accuracy: 1e-12, file: file, line: line)
        }
    }
}

private struct MixerSeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        return state
    }
}
