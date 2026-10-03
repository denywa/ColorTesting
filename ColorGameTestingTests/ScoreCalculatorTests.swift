import XCTest
@testable import ColorGameTesting

final class ScoreCalculatorTests: XCTestCase {
    func testMatchPercentageUsesNonlinearPerceptualScore() {
        let black = SIMD3<Double>(0, 0, 0)
        let white = SIMD3<Double>(100, 0, 0)
        let near = SIMD3<Double>(50, 2.6772, -79.7751)
        let target = SIMD3<Double>(50, 0, -82.7485)

        XCTAssertEqual(ScoreCalculator.matchPercentage(black, black), 100)
        XCTAssertEqual(ScoreCalculator.matchPercentage(black, white), 0, accuracy: 1e-12)
        XCTAssertEqual(ScoreCalculator.matchPercentage(near, target),
                       98.9801586, accuracy: 1e-4)
        XCTAssertEqual(ScoreCalculator.matchPercentage(black, SIMD3(100, 127, 127)), 0)
    }

    func testScreenshotColorPairsFollowPerceivedCloseness() {
        func score(_ first: SIMD3<Double>, _ second: SIMD3<Double>) -> Double {
            ScoreCalculator.matchPercentage(
                ColorConverter.sRGBToLab(first / 255),
                ColorConverter.sRGBToLab(second / 255)
            )
        }

        let redAndDarkRed = score(SIMD3(234, 51, 35), SIMD3(164, 49, 42))
        let darkBlueAndBeige = score(SIMD3(32, 64, 96), SIMD3(200, 177, 154))
        let tealAndLavender = score(SIMD3(122, 163, 163), SIMD3(200, 180, 244))

        XCTAssertGreaterThan(redAndDarkRed, 75)
        XCTAssertLessThan(redAndDarkRed, 85)
        XCTAssertGreaterThan(tealAndLavender, 25)
        XCTAssertLessThan(tealAndLavender, 40)
        XCTAssertLessThan(darkBlueAndBeige, 10)
        XCTAssertGreaterThan(redAndDarkRed, tealAndLavender)
        XCTAssertGreaterThan(tealAndLavender, darkBlueAndBeige)
    }

    func testSharmaReferencePairs() {
        // Sharma et al. (2005) supplementary data:
        // https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/dataNprograms/ciede2000testdata.txt
        let referencePairs: [(SIMD3<Double>, SIMD3<Double>, Double)] = [
            (SIMD3(50, 2.6772, -79.7751), SIMD3(50, 0, -82.7485), 2.0425),
            (SIMD3(50, 3.1571, -77.2803), SIMD3(50, 0, -82.7485), 2.8615),
            (SIMD3(50, 2.8361, -74.0200), SIMD3(50, 0, -82.7485), 3.4412),
            (SIMD3(50, -1.3802, -84.2814), SIMD3(50, 0, -82.7485), 1.0000),
            (SIMD3(50, -1.1848, -84.8006), SIMD3(50, 0, -82.7485), 1.0000),
            (SIMD3(50, -0.9009, -85.5211), SIMD3(50, 0, -82.7485), 1.0000),
            (SIMD3(50, 0, 0), SIMD3(50, -1, 2), 2.3669),
            (SIMD3(50, -1, 2), SIMD3(50, 0, 0), 2.3669),
            (SIMD3(50, 2.49, -0.001), SIMD3(50, -2.49, 0.0009), 7.1792),
            (SIMD3(50, 2.49, -0.001), SIMD3(50, -2.49, 0.0011), 7.2195),
            (SIMD3(50, -0.001, 2.49), SIMD3(50, 0.0009, -2.49), 4.8045),
            (SIMD3(50, -0.001, 2.49), SIMD3(50, 0.0011, -2.49), 4.7461),
        ]

        for (index, pair) in referencePairs.enumerated() {
            XCTAssertEqual(ScoreCalculator.deltaE2000(pair.0, pair.1), pair.2,
                           accuracy: 1e-4, "Sharma reference pair \(index + 1)")
        }
    }

    func testAchromaticAndHueWrapCases() {
        XCTAssertEqual(ScoreCalculator.deltaE2000(SIMD3(0, 0, 0), SIMD3(100, 0, 0)),
                       100.0, accuracy: 1e-12)
        XCTAssertEqual(ScoreCalculator.deltaE2000(SIMD3(50, 0, 0), SIMD3(50, 0, 0)), 0.0)

        let nearZero = SIMD3(50.0, 40.0, 0.7)
        let nearFullTurn = SIMD3(50.0, 40.0, -0.7)
        let wrappedDistance = ScoreCalculator.deltaE2000(nearZero, nearFullTurn)
        XCTAssertGreaterThan(wrappedDistance, 0.0)
        XCTAssertLessThan(wrappedDistance, 2.0)
        XCTAssertEqual(wrappedDistance,
                       ScoreCalculator.deltaE2000(nearFullTurn, nearZero), accuracy: 1e-12)
    }

    // Feature: color-mixing-game, Property 18a: Delta-E 2000 non-negativity
    // Feature: color-mixing-game, Property 18b: Delta-E 2000 identity
    // Feature: color-mixing-game, Property 19: Bounded match percentage
    func testIdentityAndNonNegativity() {
        let colors = [SIMD3(0.0, 0.0, 0.0), SIMD3(100.0, 0.0, 0.0),
                      SIMD3(50.0, -128.0, 127.0), SIMD3(23.5, 41.2, -77.9)]
        for color in colors {
            XCTAssertEqual(ScoreCalculator.deltaE2000(color, color), 0.0)
        }

        let seed: UInt64 = 0xC01A_2000
        var state = seed
        func nextUnit() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        for index in 0..<200 {
            let first = SIMD3(nextUnit() * 100, nextUnit() * 255 - 128,
                              nextUnit() * 255 - 128)
            let second = SIMD3(nextUnit() * 100, nextUnit() * 255 - 128,
                               nextUnit() * 255 - 128)
            let distance = ScoreCalculator.deltaE2000(first, second)
            let context = "seed=\(seed), iteration=\(index), first=\(first), second=\(second)"
            XCTAssertTrue(distance.isFinite, context)
            XCTAssertGreaterThanOrEqual(distance, 0.0, context)
            XCTAssertEqual(ScoreCalculator.deltaE2000(first, first), 0.0, context)
            let percentage = ScoreCalculator.matchPercentage(first, second)
            XCTAssertTrue(percentage.isFinite, context)
            XCTAssertGreaterThanOrEqual(percentage, 0, context)
            XCTAssertLessThanOrEqual(percentage, 100, context)
            XCTAssertEqual(ScoreCalculator.matchPercentage(first, first), 100, context)
        }
    }
}
