import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor
final class CustomRequestStoreTests: XCTestCase {
    func testBuiltInAndCustomEditsPersistWithoutDuplicatesAndCanBeDeleted() throws {
        let suite = "RequestEditingTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = GameViewModel(requestDefaults: defaults)
        let builtIn = try XCTUnwrap(model.availableRequests.first)
        XCTAssertTrue(model.addCustomRequest(text: "Original custom", hex: "123456"))
        let custom = try XCTUnwrap(model.customRequests.first)
        for request in [builtIn, custom] {
            XCTAssertTrue(model.editRequest(id: request.id, text: "  Edited request  ", hex: "#AB09FF", difficulty: .level3))
            XCTAssertEqual(model.availableRequests.filter { $0.id == request.id }.count, 1)
            XCTAssertEqual(model.selectedRequestID, request.id)
            XCTAssertEqual(model.selectedRequestLevel, .level3)
            XCTAssertTrue(model.editRequest(id: request.id, text: "Final request", hex: "010203", difficulty: .level2))
        }
        let reloaded = GameViewModel(requestDefaults: defaults)
        XCTAssertEqual(reloaded.availableRequests.count, ColorData.requestPool.count + 1)
        for request in [builtIn, custom] {
            let edited = try XCTUnwrap(reloaded.availableRequests.first { $0.id == request.id })
            XCTAssertEqual(edited.text, "Final request")
            XCTAssertEqual(edited.targetSRGB, ColorHex.sRGB("010203"))
            XCTAssertEqual(edited.difficulty, .level2)
            XCTAssertEqual(reloaded.availableRequests.filter { $0.id == request.id }.count, 1)
            XCTAssertTrue(reloaded.deleteRequest(id: request.id))
        }
        let afterDeletion = GameViewModel(requestDefaults: defaults)
        XCTAssertFalse(afterDeletion.availableRequests.contains { $0.id == builtIn.id || $0.id == custom.id })
    }

    func testInvalidUnknownAndInGameEditsDoNotChangeSavedRequest() throws {
        let suite = "RequestEditingValidationTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = GameViewModel(requestDefaults: defaults)
        let request = try XCTUnwrap(model.availableRequests.first)
        XCTAssertFalse(model.editRequest(id: request.id, text: " ", hex: "123456", difficulty: .level1))
        XCTAssertFalse(model.editRequest(id: request.id, text: "Changed", hex: "bad hex", difficulty: .level1))
        XCTAssertFalse(model.editRequest(id: UUID(), text: "Changed", hex: "123456", difficulty: .level1))
        XCTAssertTrue(model.customRequests.isEmpty)
        model.confirmSettings()
        defer { model.pauseTimer(); model.removeKeyMonitor() }
        XCTAssertFalse(model.editRequest(id: request.id, text: "Changed", hex: "123456", difficulty: .level1))
        XCTAssertEqual(model.availableRequests.first { $0.id == request.id }?.text, request.text)
        XCTAssertTrue(GameViewModel(requestDefaults: defaults).customRequests.isEmpty)
    }

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

        reloaded.confirmSettings()
        XCTAssertEqual(reloaded.round?.request.id, added.id)
        XCTAssertEqual(reloaded.round?.request.targetSRGB, added.targetSRGB)
        XCTAssertFalse(reloaded.addCustomRequest(text: "Too late", hex: "#123456"))
        reloaded.pauseTimer()
        reloaded.removeKeyMonitor()
    }
}
