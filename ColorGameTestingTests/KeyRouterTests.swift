import XCTest
@testable import ColorGameTesting

final class KeyRouterTests: XCTestCase {
    @MainActor func testPhysicalKeysRouteToTheAssignedPlayerAndColorSlot() {
        let expectedActions: [(UInt16, PlayerID, ColorSlot)] = [
            (12, .player1, .primary),
            (13, .player1, .secondary),
            (11, .player2, .primary),
            (45, .player2, .secondary),
            (31, .player3, .primary),
            (35, .player3, .secondary)
        ]

        for (keyCode, expectedPlayer, expectedSlot) in expectedActions {
            guard case let .addColor(player, colorSlot)? = KeyRouter.action(for: keyCode) else {
                XCTFail("Expected addColor action for key code \(keyCode)")
                continue
            }
            XCTAssertEqual(player, expectedPlayer, "Wrong player for key code \(keyCode)")
            XCTAssertEqual(colorSlot, expectedSlot, "Wrong slot for key code \(keyCode)")
        }
    }

    func testUnrecognizedKeyReturnsNil() {
        XCTAssertNil(KeyRouter.action(for: 0))
        XCTAssertNil(KeyRouter.action(for: UInt16.max))
    }
}
