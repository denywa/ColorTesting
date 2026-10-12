import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor
final class CustomRequestStoreTests: XCTestCase {
    func testHexInputAcceptsSixDigitsAndRejectsMalformedValues() {
        XCTAssertEqual(ColorHex.normalized("  #aB09fF\n"), "#AB09FF")
        XCTAssertEqual(ColorHex.normalized("ff8c32"), "#FF8C32")
        XCTAssertEqual(ColorHex.sRGB("#FF8C32"), SIMD3(1, 140.0 / 255, 50.0 / 255))
        XCTAssertNil(ColorHex.sRGB("#12345"))
        XCTAssertNil(ColorHex.sRGB("#1234567"))
        XCTAssertNil(ColorHex.sRGB("#GG8C32"))
        XCTAssertNil(ColorHex.sRGB("red"))
    }

    func testCustomRequestPersistsAndCanStartTheSelectedRound() {
        let suiteName = "ColorGameTestingTests.customRequests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = GameViewModel(requestDefaults: defaults)
        XCTAssertFalse(viewModel.addCustomRequest(text: "   ", hex: "#FF8C32"))
        XCTAssertFalse(viewModel.addCustomRequest(text: "Sunset red", hex: "#GG8C32"))
        XCTAssertTrue(viewModel.customRequests.isEmpty)

        XCTAssertTrue(viewModel.addCustomRequest(text: "  Sunset red  ", hex: "#eA3323"))
        let added = viewModel.customRequests[0]
        XCTAssertEqual(added.text, "Sunset red")
        XCTAssertEqual(added.targetSRGB, SIMD3(234.0 / 255, 51.0 / 255, 35.0 / 255))
        XCTAssertEqual(viewModel.selectedRequestID, added.id)
        XCTAssertEqual(viewModel.availableRequests.count, ColorData.requestPool.count + 1)

        let reloaded = GameViewModel(requestDefaults: defaults)
        XCTAssertEqual(reloaded.customRequests.count, 1)
        XCTAssertEqual(reloaded.customRequests[0].id, added.id)
        XCTAssertEqual(reloaded.customRequests[0].text, added.text)
        XCTAssertEqual(reloaded.customRequests[0].targetSRGB, added.targetSRGB)
        reloaded.selectedRequestID = added.id
        reloaded.selectModel(.ryb)
        reloaded.confirmSettings()
        XCTAssertEqual(reloaded.round?.request.id, added.id)
        XCTAssertEqual(reloaded.round?.request.targetSRGB, added.targetSRGB)
        XCTAssertFalse(reloaded.addCustomRequest(text: "Too late", hex: "#123456"))
        reloaded.pauseTimer()
        reloaded.removeKeyMonitor()
    }
}
