import Foundation
import XCTest
@testable import ColorGameTesting

final class ColorMixerTests: XCTestCase {
    // Feature: color-mixing-game, Property 14: Color blending is weighted arithmetic mean
    func testWeightedNativeComponentMeanForRandomCMYKMixes() {
        let seed: UInt64 = 0xC010_0014
        var generator = MixerSeededGenerator(seed: seed)

        for iteration in 0..<200 {
            let model: ColorModel = .cmyk
            let colorCount = Int.random(in: 2...5, using: &generator)
            let colors = (0..<colorCount).map { index in
                randomColor(model: model, idNumber: iteration * 8 + index + 1, using: &generator)
            }
            let counts = (0..<colorCount).map { _ in Int.random(in: 1...12, using: &generator) }
            let total = Double(counts.reduce(0, +))
            let weights = counts.map { Double($0) / total }
            let units = zip(colors, counts).flatMap { color, count in
                Array(repeating: ColorUnit(color: color), count: count)
            }

            let native = zip(colors, weights).reduce(SIMD4<Double>(repeating: 0)) { sum, pair in
                sum + pair.0.cmykComponents! * pair.1
            }
            let expected = SIMD3(
                (1 - native.x) * (1 - native.w),
                (1 - native.y) * (1 - native.w),
                (1 - native.z) * (1 - native.w)
            )

            let actual = ColorMixer.blend(units, model: model)
            let input = zip(colors, counts).map { color, count in
                "id=\(color.id), count=\(count), cmyk=\(String(describing: color.cmykComponents)), ryb=\(String(describing: color.rybComponents))"
            }.joined(separator: "; ")
            for channel in 0..<3 {
                XCTAssertEqual(
                    actual[channel], expected[channel], accuracy: 1e-12,
                    "seed=\(seed), iteration=\(iteration), model=\(model), channel=\(channel), weights=\(weights), input=[\(input)]"
                )
            }
        }
    }

    // Feature: color-mixing-game, Property 15: Single-color blend is identity
    func testRandomSingleColorIsIdentityForAnyPositiveUnitCount() {
        let seed: UInt64 = 0xC010_0015
        var generator = MixerSeededGenerator(seed: seed)

        for iteration in 0..<200 {
            let model: ColorModel = iteration.isMultiple(of: 2) ? .cmyk : .ryb
            let color = randomColor(model: model, idNumber: iteration + 1, using: &generator)
            let count = Int.random(in: 1...100, using: &generator)
            let units = Array(repeating: ColorUnit(color: color), count: count)

            XCTAssertEqual(
                ColorMixer.blend(units, model: model), color.sRGB,
                "seed=\(seed), iteration=\(iteration), model=\(model), count=\(count), id=\(color.id), sRGB=\(color.sRGB), cmyk=\(String(describing: color.cmykComponents)), ryb=\(String(describing: color.rybComponents))"
            )
        }
    }

    func testEqualWeightCyanAndMagentaCMYKMix() {
        let cyan = ColorData.cmykPalette[0]
        let magenta = ColorData.cmykPalette[1]
        let result = ColorMixer.blend([ColorUnit(color: cyan), ColorUnit(color: magenta)], model: .cmyk)
        assertRGB(result, equals: SIMD3(0.5, 0.5, 1))
    }

    func testAllWhiteCMYKMix() {
        let white = ColorData.cmykPalette[4]
        let otherWhite = NamedColor(id: UUID(), name: "White", sRGB: white.sRGB,
                                    cmykComponents: white.cmykComponents, rybComponents: nil)
        let result = ColorMixer.blend([ColorUnit(color: white), ColorUnit(color: otherWhite)], model: .cmyk)
        XCTAssertEqual(result, SIMD3(1, 1, 1))
    }

    func testCMYKBlendsFourChannelsBeforeConvertingToSRGB() {
        let cyan = ColorData.cmykPalette[0]
        let black = ColorData.cmykPalette[3]
        let result = ColorMixer.blend([ColorUnit(color: cyan), ColorUnit(color: black)], model: .cmyk)
        assertRGB(result, equals: SIMD3(0.25, 0.5, 0.5))
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

    func testExtremeCMYKWeightAndClamping() {
        let cyan = ColorData.cmykPalette[0]
        let black = ColorData.cmykPalette[3]
        let units = Array(repeating: ColorUnit(color: cyan), count: 99) + [ColorUnit(color: black)]
        assertRGB(ColorMixer.blend(units, model: .cmyk), equals: SIMD3(0.0099, 0.99, 0.99))

        let outOfRange = NamedColor(id: UUID(), name: "Out of range", sRGB: SIMD3(0, 0, 0),
                                    cmykComponents: SIMD4(-1, 2, 0, 0), rybComponents: nil)
        let white = ColorData.cmykPalette[4]
        let clamped = ColorMixer.blend([ColorUnit(color: outOfRange), ColorUnit(color: white)], model: .cmyk)
        XCTAssertEqual(clamped, SIMD3(1, 0, 1))
    }

    private func randomColor(
        model: ColorModel, idNumber: Int, using generator: inout MixerSeededGenerator
    ) -> NamedColor {
        let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", idNumber))!
        let srgb = SIMD3(
            Double.random(in: 0...1, using: &generator),
            Double.random(in: 0...1, using: &generator),
            Double.random(in: 0...1, using: &generator)
        )
        switch model {
        case .cmyk:
            return NamedColor(
                id: id, name: "Generated CMYK", sRGB: srgb,
                cmykComponents: SIMD4(
                    Double.random(in: 0...1, using: &generator),
                    Double.random(in: 0...1, using: &generator),
                    Double.random(in: 0...1, using: &generator),
                    Double.random(in: 0...1, using: &generator)
                ),
                rybComponents: nil
            )
        case .ryb:
            return NamedColor(
                id: id, name: "Generated RYB", sRGB: srgb, cmykComponents: nil,
                rybComponents: SIMD3(
                    Double.random(in: 0...1, using: &generator),
                    Double.random(in: 0...1, using: &generator),
                    Double.random(in: 0...1, using: &generator)
                )
            )
        }
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
