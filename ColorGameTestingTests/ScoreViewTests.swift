import AppKit
import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class ScoreViewTests: XCTestCase {
    func testDisplayedPercentageChangesAcrossHundredthBoundary() throws {
        let viewModel = GameViewModel()
        viewModel.phase = .score
        viewModel.score = 87.654
        let first = try render(viewModel)

        viewModel.score = 87.656
        let second = try render(viewModel)

        XCTAssertNotEqual(first, second, "The score screen must show the match percentage rounded to two decimals")
        viewModel.score = 87.651
        let sameHundredth = try render(viewModel)
        XCTAssertEqual(first, sameHundredth, "Values within one hundredth must show the same percentage")
    }

    private func render(_ viewModel: GameViewModel) throws -> Data {
        let hostingView = NSHostingView(rootView: ScoreView(viewModel: viewModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
