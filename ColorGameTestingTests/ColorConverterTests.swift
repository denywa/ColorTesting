import XCTest
@testable import ColorGameTesting

final class ColorConverterTests: XCTestCase {
    func testSRGBToLabReferenceColors() {
        assertComponents(ColorConverter.sRGBToLab(SIMD3(0, 0, 0)),
                         equalTo: SIMD3(0, 0, 0), accuracy: 1e-6)
        // The specified rounded XYZ matrix and D65 white point leave a small a*/b* residual.
        assertComponents(ColorConverter.sRGBToLab(SIMD3(1, 1, 1)),
                         equalTo: SIMD3(100, 0.001736864, 0.014087078), accuracy: 1e-3)
        assertComponents(ColorConverter.sRGBToLab(SIMD3(1, 0, 0)),
                         equalTo: SIMD3(53.2408, 80.0938, 67.2069), accuracy: 1e-3)
    }

    func testLabToSRGBReferenceColors() {
        assertComponents(ColorConverter.labToSRGB(SIMD3(0, 0, 0)),
                         equalTo: SIMD3(0, 0, 0), accuracy: 1e-6)
        assertComponents(ColorConverter.labToSRGB(SIMD3(100, 0, 0)),
                         equalTo: SIMD3(1, 1, 1), accuracy: 1e-4)
        let redLabReference = SIMD3(53.2408, 80.0938, 67.2069)
        assertComponents(ColorConverter.labToSRGB(redLabReference),
                         equalTo: SIMD3(1, 0, 0), accuracy: 1e-4)
    }

    func testLabToSRGBClampsOutOfGamutColors() {
        for lab in [SIMD3(150.0, 0.0, 0.0), SIMD3(-50.0, 0.0, 0.0),
                    SIMD3(50.0, 200.0, -200.0)] {
            let rgb = ColorConverter.labToSRGB(lab)
            for channel in 0..<3 {
                XCTAssertTrue(rgb[channel].isFinite)
                XCTAssertGreaterThanOrEqual(rgb[channel], 0)
                XCTAssertLessThanOrEqual(rgb[channel], 1)
            }
        }
        XCTAssertEqual(ColorConverter.labToSRGB(SIMD3(150, 0, 0)), SIMD3(1, 1, 1))
        XCTAssertEqual(ColorConverter.labToSRGB(SIMD3(-50, 0, 0)), SIMD3(0, 0, 0))
    }

    // Feature: color-mixing-game, Property 17: sRGB → Lab → sRGB round-trip
    func testSRGBLabSRGBRoundTripForTwoHundredRandomColorsAndEdges() {
        let seed: UInt64 = 0xC01A_BA5E
        var state = seed
        func nextComponent() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }

        let edgeColors = [SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 1.0),
                          SIMD3(1.0, 0.0, 0.0), SIMD3(0.04045, 0.5, 1.0)]
        let randomColors = (0..<200).map { _ in
            SIMD3(nextComponent(), nextComponent(), nextComponent())
        }
        for (index, input) in (edgeColors + randomColors).enumerated() {
            let output = ColorConverter.labToSRGB(ColorConverter.sRGBToLab(input))
            for channel in 0..<3 {
                XCTAssertEqual(output[channel], input[channel], accuracy: 1e-6,
                               "seed=\(seed), index=\(index), input=\(input), channel=\(channel)")
            }
        }
    }

    private func assertComponents(_ actual: SIMD3<Double>, equalTo expected: SIMD3<Double>,
                                  accuracy: Double, file: StaticString = #filePath,
                                  line: UInt = #line) {
        for channel in 0..<3 {
            XCTAssertEqual(actual[channel], expected[channel], accuracy: accuracy,
                           file: file, line: line)
        }
    }
}
