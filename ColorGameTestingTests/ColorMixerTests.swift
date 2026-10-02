import Foundation
import XCTest
@testable import ColorGameTesting

final class ColorMixerTests: XCTestCase {
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

    func testRYBBlendsNativeComponentsBeforeTrilinearConversion() {
        let red = ColorData.rybPalette[0]
        let yellow = ColorData.rybPalette[1]
        let result = ColorMixer.blend([ColorUnit(color: red), ColorUnit(color: yellow)], model: .ryb)
        assertRGB(result, equals: SIMD3(0.75, 0.375, 0))
    }

    func testRYBInterpolationUsesAllEightSpecifiedCorners() {
        let corners: [(SIMD3<Double>, SIMD3<Double>)] = [
            (SIMD3(0, 0, 0), SIMD3(0, 0, 0)),
            (SIMD3(1, 0, 0), SIMD3(1, 0, 0)),
            (SIMD3(0, 1, 0), SIMD3(1, 1, 0)),
            (SIMD3(0, 0, 1), SIMD3(0, 0, 1)),
            (SIMD3(1, 1, 0), SIMD3(1, 0.5, 0)),
            (SIMD3(1, 0, 1), SIMD3(0.5, 0, 0.5)),
            (SIMD3(0, 1, 1), SIMD3(0, 1, 0)),
            (SIMD3(1, 1, 1), SIMD3(0.5, 0.3, 0))
        ]
        for (components, expected) in corners {
            // Distinct IDs force conversion through the cube rather than identity handling.
            let first = rybColor(components)
            let second = rybColor(components)
            let result = ColorMixer.blend([ColorUnit(color: first), ColorUnit(color: second)], model: .ryb)
            assertRGB(result, equals: expected)
        }
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

        let firstRYB = rybColor(SIMD3(2, 0, 0))
        let secondRYB = rybColor(SIMD3(2, 0, 0))
        let rybClamped = ColorMixer.blend([ColorUnit(color: firstRYB), ColorUnit(color: secondRYB)], model: .ryb)
        XCTAssertEqual(rybClamped, SIMD3(1, 0, 0))
    }

    private func rybColor(_ components: SIMD3<Double>) -> NamedColor {
        NamedColor(id: UUID(), name: "Corner", sRGB: SIMD3(0.25, 0.25, 0.25),
                   cmykComponents: nil, rybComponents: components)
    }

    private func assertRGB(_ actual: SIMD3<Double>, equals expected: SIMD3<Double>,
                           file: StaticString = #filePath, line: UInt = #line) {
        for channel in 0..<3 {
            XCTAssertEqual(actual[channel], expected[channel], accuracy: 1e-12, file: file, line: line)
        }
    }
}
