import AppKit
import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class GameViewRenderingTests: XCTestCase {
    func testGameViewRendersCurrentRequestAssignmentsTimerAndMixAvailability() throws {
        let viewModel = makeFixture()
        let initial = try renderedPixels(of: viewModel)

        let originalRound = try XCTUnwrap(viewModel.round)
        viewModel.round = Round(
            request: ColorRequest(
                id: UUID(), text: "Paint a forest at dusk", targetSRGB: SIMD3(0.2, 0.4, 0.3)
            ),
            colorModel: originalRound.colorModel,
            mixMode: originalRound.mixMode,
            assignments: originalRound.assignments,
            mix: originalRound.mix
        )
        let changedRequest = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(initial, changedRequest, "The current request must be visible")

        viewModel.round = originalRound
        var changedAssignments = originalRound.assignments
        changedAssignments[.player1] = PlayerAssignment(
            player: .player1,
            primaryColor: ColorData.rybPalette[3],
            secondaryColor: ColorData.rybPalette[4]
        )
        viewModel.round?.assignments = changedAssignments
        let changedColors = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(initial, changedColors, "The panels must reflect current assignments")

        viewModel.round = originalRound
        viewModel.timerSecondsRemaining = 12
        let changedTimer = try renderedPixels(of: viewModel)
        XCTAssertEqual(initial, changedTimer, "The color reassignment countdown is intentionally hidden")

        viewModel.timerSecondsRemaining = viewModel.reassignmentDuration
        viewModel.round?.mix.units.removeAll()
        let emptyMix = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(initial, emptyMix, "The Mix button must show its disabled state")
    }

    func testColorPieRendersEmptySingleAndMultipleColorRatios() throws {
        let colors = ColorData.rybPalette

        let empty = try renderedPiePixels(of: Mix())
        XCTAssertEqual(try rgb(at: 40, 40, in: empty), try rgb(at: 120, 120, in: empty),
                       "An empty mix needs one neutral circle")
        let neutral = try rgb(at: 80, 80, in: empty)
        XCTAssertEqual(neutral.x, neutral.y, accuracy: 0.05)
        XCTAssertEqual(neutral.y, neutral.z, accuracy: 0.05)

        let single = try renderedPiePixels(of: Mix(units: [ColorUnit(color: colors[0])]))
        try assertColor(colors[0], at: 40, 40, in: single)
        try assertColor(colors[0], at: 120, 120, in: single)

        let mixed = try renderedPiePixels(of: Mix(units: [
            ColorUnit(color: colors[0]), ColorUnit(color: colors[1]),
            ColorUnit(color: colors[1]), ColorUnit(color: colors[2])
        ]))
        try assertColor(colors[0], at: 120, 40, in: mixed)
        try assertColor(colors[1], at: 120, 120, in: mixed)
        try assertColor(colors[1], at: 40, 120, in: mixed)
        try assertColor(colors[2], at: 40, 40, in: mixed)

        let changedRatio = try renderedPiePixels(of: Mix(units: [
            ColorUnit(color: colors[0]), ColorUnit(color: colors[1]),
            ColorUnit(color: colors[0]), ColorUnit(color: colors[0])
        ]))
        try assertColor(colors[0], at: 40, 120, in: changedRatio)
        try assertColor(colors[1], at: 40, 40, in: changedRatio)
    }

    func testGameViewUpdatesPieWhenMixRatiosChange() throws {
        let viewModel = makeFixture()
        let colors = ColorData.rybPalette
        viewModel.round?.mix.units = [
            ColorUnit(color: colors[0]), ColorUnit(color: colors[0]), ColorUnit(color: colors[1])
        ]
        let firstRatio = try renderedPixels(of: viewModel)

        viewModel.round?.mix.units = [
            ColorUnit(color: colors[0]), ColorUnit(color: colors[1]), ColorUnit(color: colors[1])
        ]
        let secondRatio = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(firstRatio, secondRatio,
                          "The displayed pie must react when only the mix proportions change")
    }

    func testAutoGameplayShowsEmptyThenLiveColorWithoutManualChartOrMix() throws {
        let model = makeFixture(mode: .auto)
        model.round?.mix.units.removeAll()
        var view = GameView(viewModel: model)
        XCTAssertFalse(containsChart(view.content(size: CGSize(width: 900, height: 500))))
        XCTAssertFalse(view.showsMixButton)
        XCTAssertTrue(texts(in: view.content(size: CGSize(width: 900, height: 500))).contains { $0.contains("Add a color") })
        XCTAssertEqual(Set(buttons(in: view.content(size: CGSize(width: 900, height: 500))).map(buttonTitle)), ["Apply", "Redo"])
        XCTAssertFalse(view.canApply)
        XCTAssertFalse(view.canRedo)
        let empty = try renderedPixels(of: model)

        model.addColor(player: .player1, slot: .primary)
        view = GameView(viewModel: model)
        XCTAssertNotNil(model.currentBlend)
        XCTAssertFalse(containsChart(view.content(size: CGSize(width: 900, height: 500))))
        XCTAssertFalse(texts(in: view.content(size: CGSize(width: 900, height: 500))).contains { $0.contains("Add a color") })
        XCTAssertTrue(view.canApply)
        XCTAssertTrue(view.canRedo)
        let live = try renderedPixels(of: model)
        XCTAssertNotEqual(empty, live)
        model.addColor(player: .player1, slot: .secondary)
        XCTAssertNotEqual(live, try renderedPixels(of: model),
                          "The live swatch must change after a different color is accepted")
        model.pauseTimer()
        model.removeKeyMonitor()
    }

    func testAutoGameplayButtonsForwardRedoAndApplyAndRejectEmptyActions() throws {
        let model = makeFixture(mode: .auto)
        model.round?.mix.units.removeAll()
        for name in ["Apply", "Redo"] {
            try pressButton(name, in: GameView(viewModel: model).content(size: CGSize(width: 900, height: 500)))
            XCTAssertEqual(model.phase, .playing)
            XCTAssertTrue(model.round?.mix.units.isEmpty == true)
        }
        model.addColor(player: .player1, slot: .primary)
        model.timerSecondsRemaining = 17
        let requestID = model.round?.request.id
        let primaryIDs = PlayerID.allCases.map { model.round?.assignments[$0]?.primaryColor.id }
        let secondaryIDs = PlayerID.allCases.map { model.round?.assignments[$0]?.secondaryColor.id }
        try pressButton("Redo", in: GameView(viewModel: model).content(size: CGSize(width: 900, height: 500)))
        XCTAssertEqual(model.phase, .playing)
        XCTAssertTrue(model.round?.mix.units.isEmpty == true)
        XCTAssertNil(model.currentBlend)
        XCTAssertEqual(model.round?.request.id, requestID)
        XCTAssertEqual(PlayerID.allCases.map { model.round?.assignments[$0]?.primaryColor.id }, primaryIDs)
        XCTAssertEqual(PlayerID.allCases.map { model.round?.assignments[$0]?.secondaryColor.id }, secondaryIDs)
        XCTAssertEqual(model.timerSecondsRemaining, 17)
        model.addColor(player: .player1, slot: .secondary)
        let blend = model.currentBlend
        try pressButton("Apply", in: GameView(viewModel: model).content(size: CGSize(width: 900, height: 500)))
        XCTAssertEqual(model.phase, .score)
        XCTAssertEqual(model.mixResult, blend)
        XCTAssertNotNil(model.score)
        XCTAssertTrue(model.round?.mix.isLocked == true)
        model.pauseTimer()
        model.removeKeyMonitor()
    }

    func testManualGameplayRetainsChartAndMixAndHintChangesRendering() throws {
        let model = makeFixture()
        let view = GameView(viewModel: model)
        XCTAssertTrue(containsChart(view.content(size: CGSize(width: 900, height: 500))))
        XCTAssertTrue(view.showsMixButton)
        XCTAssertEqual(Set(buttons(in: view.content(size: CGSize(width: 900, height: 500))).map(buttonTitle)), ["Mix"])
        let withoutHint = try renderedPixels(of: model)
        model.showTargetColor = true
        XCTAssertNotEqual(withoutHint, try renderedPixels(of: model))
        model.round?.mix.isLocked = true
        XCTAssertFalse(GameView(viewModel: model).canMix)
    }

    private func containsChart(_ value: Any) -> Bool {
        if let bowl = value as? MixingBowlView { return containsChart(bowl.body) }
        if value is ColorBarView { return true }
        return Mirror(reflecting: value).children.contains { containsChart($0.value) }
    }

    private func texts(in value: Any) -> [String] {
        if let bowl = value as? MixingBowlView { return texts(in: bowl.body) }
        if let text = value as? Text { return [String(describing: text)] }
        return Mirror(reflecting: value).children.flatMap { texts(in: $0.value) }
    }

    private func buttons(in value: Any) -> [Button<Text>] {
        if let button = value as? Button<Text> { return [button] }
        return Mirror(reflecting: value).children.flatMap { buttons(in: $0.value) }
    }

    private func buttonTitle(_ button: Button<Text>) -> String {
        let label = Mirror(reflecting: button).children.first { $0.label == "label" }!.value
        let text = String(describing: label)
        return text.contains("Apply") ? "Apply" : text.contains("Redo") ? "Redo" : text.contains("Mix") ? "Mix" : text
    }

    private func pressButton(_ title: String, in value: Any) throws {
        let button = try XCTUnwrap(buttons(in: value).first { buttonTitle($0) == title })
        let action = try XCTUnwrap(Mirror(reflecting: button).children.first { $0.label == "action" }?.value)
        let closure = try XCTUnwrap(Mirror(reflecting: action).children.first?.value as? @MainActor () -> Void)
        closure()
    }

    private func renderedPiePixels(of mix: Mix) throws -> NSBitmapImageRep {
        let hostingView = NSHostingView(rootView: ColorBarView(mix: mix).frame(width: 160, height: 160))
        hostingView.frame = NSRect(x: 0, y: 0, width: 160, height: 160)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return bitmap
    }

    private func rgb(at x: Int, _ y: Int, in bitmap: NSBitmapImageRep) throws -> SIMD3<Double> {
        let pixelX = x * bitmap.pixelsWide / 160
        let pixelY = y * bitmap.pixelsHigh / 160
        let pixel = try XCTUnwrap(bitmap.colorAt(x: pixelX, y: pixelY)?.usingColorSpace(.deviceRGB))
        return SIMD3(pixel.redComponent, pixel.greenComponent, pixel.blueComponent)
    }

    private func assertColor(_ color: NamedColor, at x: Int, _ y: Int, in bitmap: NSBitmapImageRep,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let actual = try rgb(at: x, y, in: bitmap)
        for component in 0..<3 {
            XCTAssertEqual(actual[component], color.sRGB[component], accuracy: 0.27,
                           "The pie sector at (\(x), \(y)) must use \(color.name)'s sRGB color",
                           file: file, line: line)
        }
    }

    private func makeFixture(mode: MixMode = .manual) -> GameViewModel {
        let colors = ColorData.rybPalette
        let viewModel = GameViewModel()
        viewModel.phase = .playing
        viewModel.round = Round(
            request: ColorData.requestPool[0],
            colorModel: .ryb,
            mixMode: mode,
            assignments: [
                .player1: PlayerAssignment(player: .player1, primaryColor: colors[0], secondaryColor: colors[1]),
                .player2: PlayerAssignment(player: .player2, primaryColor: colors[1], secondaryColor: colors[2]),
                .player3: PlayerAssignment(player: .player3, primaryColor: colors[2], secondaryColor: colors[0])
            ],
            mix: Mix(units: [ColorUnit(color: colors[0])])
        )
        return viewModel
    }

    private func renderedPixels(of viewModel: GameViewModel) throws -> Data {
        let hostingView = NSHostingView(rootView: GameView(viewModel: viewModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
