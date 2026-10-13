import XCTest
@testable import ColorGameTesting

final class MixRatiosTests: XCTestCase {
    // Feature: color-mixing-game, Property 6: Mix ratios sum to 1.0
    func testNonemptyMixRatiosSumToOneForRandomRYBUnits() {
        let seed: UInt64 = 0xC010_2026
        var generator = SeededGenerator(seed: seed)
        var lengths = Array(repeating: Array(1...50), count: 4).flatMap { $0 }
        lengths.shuffle(using: &generator)

        let colors = ColorData.rybPalette
        for (iteration, length) in lengths.enumerated() {
            let units = (0..<length).map { _ in
                ColorUnit(color: colors.randomElement(using: &generator)!)
            }

            let sum = Mix(units: units).ratios.values.reduce(0, +)
            let input = units.map { "\($0.color.name):\($0.color.id.uuidString)" }
                .joined(separator: ", ")
            XCTAssertEqual(
                sum, 1.0, accuracy: 1e-9,
                "seed=\(seed), iteration=\(iteration), length=\(length), input=[\(input)]"
            )
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        return state
    }
}
