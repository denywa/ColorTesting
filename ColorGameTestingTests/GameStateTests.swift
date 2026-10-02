import XCTest
@testable import ColorGameTesting

final class GameStateTests: XCTestCase {
    private let cyan = NamedColor(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Cyan",
        sRGB: SIMD3(0, 1, 1),
        cmykComponents: SIMD4(1, 0, 0, 0),
        rybComponents: nil
    )
    private let magenta = NamedColor(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "Magenta",
        sRGB: SIMD3(1, 0, 1),
        cmykComponents: SIMD4(0, 1, 0, 0),
        rybComponents: nil
    )

    func testEmptyMixHasNoRatiosAndDefaultsUnlocked() {
        let mix = Mix()
        XCTAssertTrue(mix.units.isEmpty)
        XCTAssertFalse(mix.isLocked)
        XCTAssertTrue(mix.ratios.isEmpty)
    }

    func testRatiosCountColorIDsAndSumToOne() {
        let mix = Mix(units: [
            ColorUnit(color: cyan), ColorUnit(color: magenta),
            ColorUnit(color: cyan), ColorUnit(color: cyan)
        ])
        XCTAssertEqual(mix.ratios.count, 2)
        XCTAssertEqual(mix.ratios[cyan.id] ?? -1, 0.75, accuracy: 1e-9)
        XCTAssertEqual(mix.ratios[magenta.id] ?? -1, 0.25, accuracy: 1e-9)
        XCTAssertEqual(mix.ratios.values.reduce(0, +), 1.0, accuracy: 1e-9)
    }

    func testRatiosRecalculateWhenUnitsChange() {
        var mix = Mix(units: [ColorUnit(color: cyan)])
        XCTAssertEqual(mix.ratios[cyan.id] ?? -1, 1.0, accuracy: 1e-9)
        mix.units.append(ColorUnit(color: magenta))
        XCTAssertEqual(mix.ratios[cyan.id] ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mix.ratios[magenta.id] ?? -1, 0.5, accuracy: 1e-9)
        mix.units.removeAll()
        XCTAssertTrue(mix.ratios.isEmpty)
    }

    func testEveryGeneratedNonemptyMixHasNormalizedRatios() {
        let initialSeed: UInt64 = 0xC010A
        var seed = initialSeed
        for iteration in 0..<200 {
            seed = seed &* 2_862_933_555_777_941_757 &+ 3_037_000_493
            let count = Int(seed % 32) + 1
            let units = (0..<count).map { index in
                ColorUnit(color: index.isMultiple(of: 3) ? cyan : magenta)
            }
            let ratios = Mix(units: units).ratios
            XCTAssertEqual(
                ratios.values.reduce(0, +), 1.0, accuracy: 1e-9,
                "seed=\(initialSeed), iteration=\(iteration), count=\(count)"
            )
        }
    }

    @MainActor func testRoundAndGameStateHaveValueSemantics() {
        var assignment = PlayerAssignment(player: .player1, primaryColor: cyan, secondaryColor: magenta)
        XCTAssertEqual(assignment.player, .player1)
        XCTAssertEqual(assignment.primaryColor, cyan)
        assignment.primaryColor = magenta
        XCTAssertEqual(assignment.primaryColor, magenta)

        let round = Round(
            request: ColorRequest(), colorModel: .cmyk,
            assignments: [.player1: assignment],
            mix: Mix(units: [ColorUnit(color: cyan)])
        )
        var state = GameState()
        XCTAssertNil(state.selectedModel)
        XCTAssertNil(state.round)
        XCTAssertNil(state.mixResult)
        XCTAssertNil(state.score)

        state.selectedModel = .cmyk
        state.round = round
        state.mixResult = SIMD3(0.2, 0.3, 0.4)
        state.score = 12.5
        var copy = state
        copy.round!.assignments[.player1]!.secondaryColor = cyan
        XCTAssertEqual(copy.round!.mix.units[0].color, cyan)
        copy.round!.mix.units.append(ColorUnit(color: magenta))
        copy.round!.mix.isLocked = true
        copy.score = 0

        XCTAssertEqual(state.selectedModel, .cmyk)
        XCTAssertEqual(state.round?.colorModel, .cmyk)
        XCTAssertEqual(state.round?.assignments[.player1]?.secondaryColor, magenta)
        XCTAssertEqual(state.round?.mix.units.count, 1)
        XCTAssertFalse(state.round!.mix.isLocked)
        XCTAssertEqual(state.mixResult, SIMD3(0.2, 0.3, 0.4))
        XCTAssertEqual(state.score, 12.5)
        XCTAssertEqual(copy.round?.mix.units.count, 2)
        XCTAssertEqual(copy.score, 0)
    }
}
