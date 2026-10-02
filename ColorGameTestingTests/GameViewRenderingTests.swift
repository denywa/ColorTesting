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

        viewModel.timerSecondsRemaining = 45
        viewModel.round?.mix.units.removeAll()
        let emptyMix = try renderedPixels(of: viewModel)
        XCTAssertNotEqual(initial, emptyMix, "The Mix button must show its disabled state")
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
