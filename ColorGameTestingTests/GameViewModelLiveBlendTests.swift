import XCTest
@testable import ColorGameTesting

@MainActor
final class GameViewModelLiveBlendTests: XCTestCase {
    func testSoloAutoUpdatesEveryAcceptedUnitFromWholeBowlAndKeepsPlaying() {
        let model = makeAutoRound()
        defer { model.endLocalPlay() }
        XCTAssertNil(model.currentBlend)
        for (index, action) in [(PlayerID.player1, ColorSlot.primary), (.player1, .secondary), (.player1, .primary)].enumerated() {
            let assignment = model.round!.assignments[action.0]!
            let color = action.1 == .primary ? assignment.primaryColor : assignment.secondaryColor
            model.addColor(player: action.0, slot: action.1)
            XCTAssertEqual(model.round?.mix.units.count, index + 1)
            XCTAssertEqual(model.round?.mix.units.last?.color, color)
            XCTAssertEqual(model.currentBlend, ColorMixer.blend(model.round!.mix.units, model: .ryb))
            XCTAssertEqual(model.phase, .playing)
            XCTAssertNil(model.mixResult)
            XCTAssertNil(model.score)
        }
    }

    func testHostAcceptedColorsPublishExactlyOnceWithUpdatedWholeBowlBlend() {
        let model = makeAutoRound()
        defer { model.endLocalPlay() }
        model.configureLocalPlay(localPlayer: .player1, isHost: true) { _, _ in }
        var publishedBlends: [SIMD3<Double>?] = []
        model.didChange = { publishedBlends.append(model.currentBlend) }
        let earlierColor = model.round!.assignments[.player2]!.primaryColor
        model.triggerReassignment()
        publishedBlends.removeAll()
        let otherColor = ColorData.rybPalette.first { $0.id != earlierColor.id }!
        for color in [earlierColor, otherColor, earlierColor] {
            let previousCount = model.round!.mix.units.count
            XCTAssertTrue(model.acceptColor(color, for: .player2))
            XCTAssertEqual(model.round?.mix.units.count, previousCount + 1)
            let expected = ColorMixer.blend(model.round!.mix.units, model: .ryb)
            XCTAssertEqual(model.currentBlend, expected)
            XCTAssertEqual(publishedBlends.count, previousCount + 1)
            XCTAssertEqual(publishedBlends.last!, expected)
        }
        XCTAssertNil(model.mixResult)
        XCTAssertEqual(model.phase, .playing)
    }

    func testRemoteAutoCopiesHostColorWithoutCalculatingOrMutatingLocally() {
        let host = makeAutoRound()
        defer { host.endLocalPlay() }
        host.addColor(player: .player1, slot: .primary)
        var state = host.gameState
        let transmittedColor = SIMD3(0.123, 0.456, 0.789)
        state.currentBlend = transmittedColor
        XCTAssertNotEqual(transmittedColor, ColorMixer.blend(state.round!.mix.units, model: .ryb))
        let client = GameViewModel()
        defer { client.endLocalPlay() }
        var routedInputs = 0
        client.configureLocalPlay(localPlayer: .player2, isHost: false) { _, _ in routedInputs += 1 }
        client.applyRemoteState(state, phase: .playing, timerSecondsRemaining: 12,
                                reassignmentDuration: 30, showTargetColor: true)
        XCTAssertEqual(client.currentBlend, transmittedColor)
        client.addColor(player: .player1, slot: .primary)
        client.addColor(player: .player2, slot: .primary)
        XCTAssertEqual(routedInputs, 1)
        XCTAssertFalse(client.acceptColor(ColorData.rybPalette[0], for: .player2))
        client.timerTick()
        client.triggerReassignment()
        XCTAssertEqual(client.currentBlend, transmittedColor)
        XCTAssertEqual(client.round?.mix.units.count, 1)
        XCTAssertEqual(client.timerSecondsRemaining, 12)
        client.applyRemoteState(GameState(), phase: .settings, timerSecondsRemaining: 30,
                                reassignmentDuration: 30, showTargetColor: false)
        XCTAssertNil(client.currentBlend)
    }

    func testAutoReassignmentRetainsBlendAndNextKeyUsesCurrentSlot() {
        let model = makeAutoRound()
        defer { model.endLocalPlay() }
        model.pressKey(KeyCode.q.rawValue)
        let blend = model.currentBlend
        XCTAssertNotNil(blend)
        let units = model.round!.mix.units.map(\.color.id)
        model.timerSecondsRemaining = 1
        model.timerTick()
        XCTAssertEqual(model.round!.mix.units.map(\.color.id), units)
        XCTAssertEqual(model.currentBlend, blend)
        XCTAssertEqual(model.timerSecondsRemaining, model.reassignmentDuration)
        let assignedColor = model.round!.assignments[.player1]!.secondaryColor
        model.pressKey(KeyCode.w.rawValue)
        XCTAssertEqual(model.round?.mix.units.last?.color, assignedColor)
        XCTAssertEqual(model.currentBlend, ColorMixer.blend(model.round!.mix.units, model: .ryb))
    }

    func testInvalidAutoInputsDoNotChangeBlendUnitsOrPublish() {
        let model = makeAutoRound()
        defer { model.endLocalPlay() }
        model.addColor(player: .player1, slot: .primary)
        let blend = model.currentBlend
        XCTAssertNotNil(blend)
        model.pressKey(999)
        model.round?.assignments.removeValue(forKey: .player3)
        model.addColor(player: .player3, slot: .primary)
        model.configureLocalPlay(localPlayer: .player1, isHost: true) { _, _ in }
        var changes = 0
        model.didChange = { changes += 1 }
        XCTAssertFalse(model.acceptColor(ColorData.rybPalette[0], for: .player3))
        let paletteColor = ColorData.rybPalette[0]
        let unknownColor = NamedColor(id: UUID(), name: paletteColor.name, sRGB: paletteColor.sRGB,
                                     rybComponents: paletteColor.rybComponents)
        XCTAssertFalse(model.acceptColor(unknownColor, for: .player2))
        model.round?.mix.isLocked = true
        model.addColor(player: .player1, slot: .primary)
        XCTAssertFalse(model.acceptColor(ColorData.rybPalette[0], for: .player2))
        let remaining = model.timerSecondsRemaining
        model.timerTick()
        XCTAssertEqual(model.currentBlend, blend)
        XCTAssertEqual(model.round?.mix.units.count, 1)
        XCTAssertEqual(model.timerSecondsRemaining, remaining)
        XCTAssertEqual(changes, 0)
    }

    func testLiveBlendClearsWhenLeavingPlayingRedoAndReset() {
        let model = makeAutoRound()
        defer { model.endLocalPlay() }
        model.addColor(player: .player1, slot: .primary)
        XCTAssertNotNil(model.currentBlend)
        model.pressMixButton()
        XCTAssertEqual(model.phase, .result)
        XCTAssertNil(model.currentBlend)
        XCTAssertNotNil(model.mixResult)
        model.selectRedo()
        XCTAssertNil(model.currentBlend)
        model.addColor(player: .player1, slot: .primary)
        XCTAssertNotNil(model.currentBlend)
        model.phase = .score
        XCTAssertNil(model.currentBlend)
        model.startNewRound()
        XCTAssertNil(model.currentBlend)
        model.selectMixMode(.auto)
        model.confirmSettings()
        XCTAssertNil(model.currentBlend)
        model.addColor(player: .player1, slot: .primary)
        XCTAssertNotNil(model.currentBlend)
        model.endLocalPlay()
        XCTAssertNil(model.currentBlend)
    }

    func testManualInputNeverCreatesLiveBlendIncludingHostPath() {
        let model = GameViewModel()
        defer { model.endLocalPlay() }
        XCTAssertNil(model.currentBlend)
        model.confirmSettings()
        model.addColor(player: .player1, slot: .primary)
        XCTAssertNil(model.currentBlend)
        model.configureLocalPlay(localPlayer: .player1, isHost: true) { _, _ in }
        XCTAssertTrue(model.acceptColor(ColorData.rybPalette[1], for: .player2))
        XCTAssertNil(model.currentBlend)
        model.pressMixButton()
        XCTAssertNil(model.currentBlend)
        model.selectFinish()
        XCTAssertNil(model.currentBlend)
    }

    private func makeAutoRound() -> GameViewModel {
        let model = GameViewModel()
        model.selectMixMode(.auto)
        model.confirmSettings()
        model.pauseTimer()
        return model
    }
}
