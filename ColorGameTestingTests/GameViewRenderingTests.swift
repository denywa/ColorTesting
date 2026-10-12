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
            assignments: originalRound.assignments,
            mix: originalRound.mix
        )
        let changedRequest = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(initial, changedRequest, "The current request must be visible")

        viewModel.round = originalRound
        var changedAssignments = originalRound.assignments
        changedAssignments[.player1] = PlayerAssignment(
            player: .player1,
            primaryColor: ColorData.cmykPalette[3],
            secondaryColor: ColorData.cmykPalette[4]
        )
        viewModel.round?.assignments = changedAssignments
        let changedColors = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(initial, changedColors, "The panels must reflect current assignments")

        viewModel.round = originalRound
        viewModel.timerSecondsRemaining = 12
        let changedTimer = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(initial, changedTimer, "The countdown must be visible")

        viewModel.timerSecondsRemaining = viewModel.reassignmentDuration
        viewModel.round?.mix.units.removeAll()
        let emptyMix = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(initial, emptyMix, "The Mix button must show its disabled state")
    }

    func testColorPieRendersEmptySingleAndMultipleColorRatios() throws {
        let colors = ColorData.cmykPalette

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
        let colors = ColorData.cmykPalette
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

    private func makeFixture() -> GameViewModel {
        let colors = ColorData.cmykPalette
        let viewModel = GameViewModel()
        viewModel.phase = .playing
        viewModel.round = Round(
            request: ColorData.requestPool[0],
            colorModel: .cmyk,
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
