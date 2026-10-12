import AppKit
import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class ResultViewTests: XCTestCase {
    func testBreakdownUsesFirstContributionOrderExactCountsAndOneDecimalPercentages() {
        let red = ColorData.rybPalette[0]
        let yellow = ColorData.rybPalette[1]
        let mix = Mix(units: [
            ColorUnit(color: yellow), ColorUnit(color: red),
            ColorUnit(color: yellow), ColorUnit(color: yellow)
        ])

        let rows = ResultView.breakdown(for: mix)

        XCTAssertEqual(rows.map(\.color.id), [yellow.id, red.id])
        XCTAssertEqual(rows.map(\.count), [3, 1])
        XCTAssertEqual(rows.map(\.percentage), [75.0, 25.0])

        let thirds = ResultView.breakdown(for: Mix(units: [
            ColorUnit(color: red), ColorUnit(color: yellow), ColorUnit(color: red)
        ]))
        XCTAssertEqual(thirds.map(\.percentage), [66.7, 33.3])
    }

    func testDisplayedPercentagesRoundEachColorIndependently() {
        let colors = ColorData.rybPalette
        let counts = [1, 1, 3, 8, 1]
        let units = zip(colors, counts).flatMap { color, count in
            Array(repeating: ColorUnit(color: color), count: count)
        }

        let rows = ResultView.breakdown(for: Mix(units: units))

        XCTAssertEqual(rows.map(\.count), counts)
        XCTAssertEqual(rows.map(\.percentage), [7.1, 7.1, 21.4, 57.1, 7.1])
        XCTAssertTrue(rows.allSatisfy { ($0.percentage * 10).rounded() == $0.percentage * 10 })
    }

    func testRenderedResultRespondsToSwatchAndBreakdownChanges() throws {
        let viewModel = fixture()
        let original = try render(viewModel)

        viewModel.mixResult = SIMD3(0.9, 0.1, 0.3)
        let changedSwatch = try render(viewModel)
        XCTAssertNotEqual(original, changedSwatch, "The swatch must use the current mix result")

        viewModel.mixResult = SIMD3(0.2, 0.7, 0.4)
        viewModel.round?.mix.units.append(ColorUnit(color: ColorData.rybPalette[1]))
        let changedBreakdown = try render(viewModel)
        XCTAssertNotEqual(original, changedBreakdown, "The table must show updated counts and ratios")
    }

    func testMissingResultOrRoundShowsNoMixResultInsteadOfBreakdown() throws {
        let fallback = try render(ContentUnavailableView("No Mix Result", systemImage: "paintpalette"))
        let viewModel = fixture()
        XCTAssertNotEqual(try render(viewModel), fallback)

        viewModel.mixResult = nil
        XCTAssertEqual(try render(viewModel), fallback)

        viewModel.mixResult = SIMD3(0.2, 0.7, 0.4)
        viewModel.round = nil
        XCTAssertEqual(try render(viewModel), fallback)
    }

    private func fixture() -> GameViewModel {
        let viewModel = GameViewModel()
        let red = ColorData.rybPalette[0]
        let yellow = ColorData.rybPalette[1]
        viewModel.phase = .result
        viewModel.round = Round(
            request: ColorData.requestPool[0], colorModel: .ryb,
            assignments: [:],
            mix: Mix(units: [ColorUnit(color: red), ColorUnit(color: yellow)], isLocked: true)
        )
        viewModel.mixResult = SIMD3(0.2, 0.7, 0.4)
        return viewModel
    }

    private func render(_ viewModel: GameViewModel) throws -> Data {
        try render(ResultView(viewModel: viewModel))
    }

    private func render<V: View>(_ view: V) throws -> Data {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 720, height: 760)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
