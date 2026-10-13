import XCTest
@testable import ColorGameTesting

final class GameModelsTests: XCTestCase {
    func testColorModelsAndGamePhasesHaveSpecifiedCases() {
        XCTAssertEqual(ColorModel.allCases.map(\.rawValue), ["RYB"])
        XCTAssertNil(ColorModel(rawValue: "CMYK"))

        let phases: [GamePhase] = [.settings, .playing, .result, .score]
        XCTAssertEqual(phases.count, 4)
    }

    func testEveryPlayerHasTheSpecifiedPhysicalKeysAndLabels() {
        let expectations: [(PlayerID, KeyCode, KeyCode, String, String)] = [
            (.player1, .q, .w, "Q", "W"),
            (.player2, .b, .n, "B", "N"),
            (.player3, .o, .p, "O", "P")
        ]

        XCTAssertEqual(PlayerID.allCases.count, expectations.count)
        for (player, primary, secondary, primaryLabel, secondaryLabel) in expectations {
            XCTAssertEqual(player.keys.primary, primary)
            XCTAssertEqual(player.keys.secondary, secondary)
            XCTAssertEqual(player.keyLabels.0, primaryLabel)
            XCTAssertEqual(player.keyLabels.1, secondaryLabel)
        }
    }

    func testPhysicalKeyCodesMatchMacHardwareCodes() {
        XCTAssertEqual(KeyCode.q.rawValue, 12)
        XCTAssertEqual(KeyCode.w.rawValue, 13)
        XCTAssertEqual(KeyCode.b.rawValue, 11)
        XCTAssertEqual(KeyCode.n.rawValue, 45)
        XCTAssertEqual(KeyCode.o.rawValue, 31)
        XCTAssertEqual(KeyCode.p.rawValue, 35)
    }

    func testColorSlotHasPrimaryAndSecondaryChoices() {
        let slots: [ColorSlot] = [.primary, .secondary]
        XCTAssertEqual(slots.count, 2)
    }

    @MainActor func testNamedColorPreservesComponentsAndHasValueHashing() {
        let id = UUID()
        let first = NamedColor(
            id: id,
            name: "Red",
            sRGB: SIMD3(1.0, 0.0, 0.0),
            rybComponents: SIMD3(1.0, 0.0, 0.0)
        )
        let duplicate = NamedColor(
            id: id,
            name: "Red",
            sRGB: SIMD3(1.0, 0.0, 0.0),
            rybComponents: SIMD3(1.0, 0.0, 0.0)
        )
        let other = NamedColor(
            id: UUID(),
            name: "Red",
            sRGB: SIMD3(1.0, 0.0, 0.0),
            rybComponents: SIMD3(1.0, 0.0, 0.0)
        )
        let changedComponents = NamedColor(
            id: id,
            name: "Red",
            sRGB: SIMD3(1.0, 0.0, 0.0),
            rybComponents: SIMD3(0.5, 0.0, 0.0)
        )

        XCTAssertEqual(first.id, id)
        XCTAssertEqual(first.name, "Red")
        XCTAssertEqual(first.sRGB, SIMD3(1.0, 0.0, 0.0))
        XCTAssertEqual(first.rybComponents, SIMD3(1.0, 0.0, 0.0))
        XCTAssertEqual(other.rybComponents, SIMD3(1.0, 0.0, 0.0))
        XCTAssertEqual(first, duplicate)
        XCTAssertNotEqual(first, other)
        XCTAssertNotEqual(first, changedComponents)
        XCTAssertEqual(Set([first, duplicate, other, changedComponents]).count, 3)
    }
}
