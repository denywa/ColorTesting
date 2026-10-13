import Foundation
import XCTest
@testable import ColorGameTesting

@MainActor
final class RequestDifficultyTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "RequestDifficultyTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    func testDeletingBuiltInAndCustomRequestsPersistsAndClearsSelection() throws {
        try withDefaults { defaults in
            let model = GameViewModel(requestDefaults: defaults)
            let builtIn = ColorData.requestPool[5]
            model.selectedRequestID = builtIn.id
            XCTAssertTrue(model.deleteRequest(id: builtIn.id))
            XCTAssertNil(model.selectedRequestID)
            XCTAssertFalse(model.availableRequests.contains { $0.id == builtIn.id })
            XCTAssertFalse(model.deleteRequest(id: builtIn.id))
            XCTAssertTrue(model.addCustomRequest(text: "Delete me", hex: "123456", difficulty: .level2))
            let customID = try XCTUnwrap(model.customRequests.last?.id)
            XCTAssertTrue(model.deleteRequest(id: customID))
            XCTAssertNil(model.selectedRequestID)
            let reloaded = GameViewModel(requestDefaults: defaults)
            XCTAssertFalse(reloaded.availableRequests.contains { $0.id == builtIn.id || $0.id == customID })
            XCTAssertEqual(reloaded.availableRequests.count, ColorData.requestPool.count - 1)
        }
    }

    func testEmptyRequiredLevelBlocksRunAndAddingReplacementRestoresIt() {
        withDefaults { defaults in
            let model = GameViewModel(requestDefaults: defaults)
            for request in model.requestsForSelectedLevel { XCTAssertTrue(model.deleteRequest(id: request.id)) }
            XCTAssertEqual(model.missingRequestLevels, [.level1])
            XCTAssertFalse(model.canStartRun)
            XCTAssertTrue(model.addCustomRequest(text: "Only request", hex: "123456", difficulty: .level1))
            XCTAssertTrue(model.canStartRun)
            let id = model.customRequests[0].id
            model.startEndlessRun()
            defer { model.returnToSettings() }
            XCTAssertEqual(model.round?.request.id, id)
            XCTAssertFalse(model.deleteRequest(id: id), "Active runs cannot change their pools")
        }
    }

    func testGuestCannotDeleteRequests() {
        withDefaults { defaults in
            let model = GameViewModel(requestDefaults: defaults)
            model.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
            XCTAssertFalse(model.deleteRequest(id: ColorData.requestPool[0].id))
            XCTAssertEqual(model.availableRequests.count, ColorData.requestPool.count)
        }
    }

    func testBuiltInClassificationPreservesEveryExistingTarget() {
        let expected: [(String, String, String, RequestDifficulty)] = [
            ("001", "Glossy mocha brown", "#4A3B32", .level3),
            ("002", "Milk tea", "#C8B19A", .level3),
            ("003", "Honey blonde", "#F6D48B", .level2),
            ("004", "Lavender", "#C8B4F4", .level2),
            ("005", "Sky blue", "#87CEFA", .level2),
            ("006", "Red blood", "#B22222", .level1),
            ("007", "Juicy orange", "#FF8C32", .level1)
        ]
        XCTAssertEqual(ColorData.requestPool.count, expected.count)
        XCTAssertEqual(Set(ColorData.requestPool.map(\.id)).count, expected.count)
        for (request, fixture) in zip(ColorData.requestPool, expected) {
            XCTAssertEqual(request.id, UUID(uuidString: "C0000000-0000-0000-0000-000000000\(fixture.0)"))
            XCTAssertEqual(request.text, fixture.1)
            XCTAssertEqual(ColorHex.string(from: request.targetSRGB), fixture.2)
            XCTAssertEqual(request.difficulty, fixture.3)
        }
        for level in RequestDifficulty.allCases {
            XCTAssertFalse(ColorData.requestPool.filter { $0.difficulty == level }.isEmpty)
        }
    }

    func testSelectingLevelsFiltersCatalogAndClearsIncompatibleChoices() {
        withDefaults { defaults in
            let model = GameViewModel(requestDefaults: defaults)
            XCTAssertEqual(model.selectedRequestLevel, .level1)
            XCTAssertEqual(Set(model.requestsForSelectedLevel.map(\.text)), ["Red blood", "Juicy orange"])
            model.selectedRequestID = ColorData.requestPool[5].id
            model.selectedRequestLevel = .level2
            XCTAssertNil(model.selectedRequestID)
            XCTAssertEqual(Set(model.requestsForSelectedLevel.map(\.text)), ["Sky blue", "Lavender", "Honey blonde"])
            model.selectedRequestID = ColorData.requestPool[0].id
            XCTAssertEqual(model.selectedRequestLevel, .level3, "Existing explicit-selection callers must keep working")
            model.confirmSettings()
            XCTAssertEqual(model.round?.request.id, ColorData.requestPool[0].id)
            model.selectedRequestLevel = .level1
            XCTAssertEqual(model.selectedRequestLevel, .level3, "Level changes require settings")
            model.pauseTimer()
            model.removeKeyMonitor()
        }
    }

    func testRandomNeverLeavesTheSelectedLevel() {
        withDefaults { defaults in
            for level in RequestDifficulty.allCases {
                for _ in 0..<20 {
                    let model = GameViewModel(requestDefaults: defaults)
                    model.selectedRequestLevel = level
                    model.confirmSettings()
                    XCTAssertEqual(model.round?.request.difficulty, level)
                    XCTAssertTrue(model.requestsForSelectedLevel.contains { $0.id == model.round?.request.id })
                    model.pauseTimer()
                    model.removeKeyMonitor()
                }
            }
        }
    }

    func testCustomLevelsPersistAndSaveSelectsTheRequestedLevel() {
        withDefaults { defaults in
            let model = GameViewModel(requestDefaults: defaults)
            model.selectedRequestLevel = .level2
            XCTAssertTrue(model.addCustomRequest(text: "Medium target", hex: "#123456"))
            XCTAssertEqual(model.customRequests.last?.difficulty, .level2)
            for level in RequestDifficulty.allCases {
                XCTAssertTrue(model.addCustomRequest(text: "  Target \(level.rawValue)  ", hex: "#abcdef", difficulty: level))
                XCTAssertEqual(model.selectedRequestLevel, level)
                XCTAssertEqual(model.selectedRequestID, model.customRequests.last?.id)
                XCTAssertTrue(model.requestsForSelectedLevel.contains { $0.id == model.selectedRequestID })
            }
            let reloaded = GameViewModel(requestDefaults: defaults)
            XCTAssertEqual(reloaded.customRequests.map(\.id), model.customRequests.map(\.id))
            XCTAssertEqual(reloaded.customRequests.map(\.difficulty), model.customRequests.map(\.difficulty))
            XCTAssertEqual(reloaded.customRequests.map(\.targetSRGB), model.customRequests.map(\.targetSRGB))
            XCTAssertEqual(reloaded.selectedRequestLevel, .level1)
            let selected = model.selectedRequestID
            XCTAssertFalse(model.addCustomRequest(text: " ", hex: "#000000", difficulty: .level1))
            XCTAssertFalse(model.addCustomRequest(text: "Invalid", hex: "no", difficulty: .level1))
            XCTAssertEqual(model.selectedRequestLevel, .level3)
            XCTAssertEqual(model.selectedRequestID, selected)
        }
    }

    func testLegacyAndInvalidStoredRecordsPreserveValidNeighbors() throws {
        try withDefaults { defaults in
            let legacyID = UUID(), modernID = UUID()
            let records: [[String: Any]] = [
                ["id": legacyID.uuidString, "text": "Legacy", "hex": "#123456"],
                ["id": modernID.uuidString, "text": "New", "hex": "#ABCDEF", "difficulty": 3],
                ["id": UUID().uuidString, "text": "Unknown level", "hex": "#123456", "difficulty": 99],
                ["id": UUID().uuidString, "text": "  ", "hex": "#123456"],
                ["id": UUID().uuidString, "text": "Invalid color", "hex": "invalid"]
            ]
            defaults.set(try JSONSerialization.data(withJSONObject: records), forKey: "customColorRequests.v1")
            let model = GameViewModel(requestDefaults: defaults)
            XCTAssertEqual(model.customRequests.map(\.id), [legacyID, modernID])
            XCTAssertEqual(model.customRequests.map(\.difficulty), [.level1, .level3])
            XCTAssertEqual(model.customRequests.first?.targetSRGB, ColorHex.sRGB("#123456"))
            XCTAssertEqual(model.availableRequests.count, ColorData.requestPool.count + 2)
            defaults.set(Data("not JSON".utf8), forKey: "customColorRequests.v1")
            let malformed = GameViewModel(requestDefaults: defaults)
            XCTAssertTrue(malformed.customRequests.isEmpty)
            XCTAssertEqual(malformed.availableRequests.count, ColorData.requestPool.count)
        }
    }

    func testNewRoundRetainsLevelAndStillResetsManualMode() {
        withDefaults { defaults in
            let model = GameViewModel(requestDefaults: defaults)
            model.selectedRequestLevel = .level3
            model.selectMixMode(.auto)
            model.confirmSettings()
            model.addColor(player: .player1, slot: .primary)
            model.selectApply()
            XCTAssertEqual(model.phase, .score)
            model.startNewRound()
            XCTAssertEqual(model.phase, .settings)
            XCTAssertEqual(model.selectedRequestLevel, .level3)
            XCTAssertEqual(model.selectedMixMode, .manual)
            XCTAssertNil(model.selectedRequestID)
        }
    }

    func testLevelSelectionAndAdditionRequireSetupAuthority() {
        withDefaults { defaults in
            let host = GameViewModel(requestDefaults: defaults)
            host.configureLocalPlay(localPlayer: .player1, isHost: true) { _, _ in }
            var changes = 0
            host.didChange = { changes += 1 }
            host.selectedRequestLevel = .level2
            host.selectedRequestLevel = .level2
            XCTAssertEqual(changes, 1)
            let client = GameViewModel(requestDefaults: defaults)
            client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in }
            client.selectedRequestLevel = .level3
            client.selectedRequestID = ColorData.requestPool[0].id
            XCTAssertEqual(client.selectedRequestLevel, .level1)
            XCTAssertNil(client.selectedRequestID)
            XCTAssertFalse(client.addCustomRequest(text: "Client", hex: "#123456", difficulty: .level3))
            XCTAssertTrue(client.customRequests.isEmpty)
        }
    }
}
