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

    func testComparisonUsesBothScoredMixAndTargetColors() throws {
        let viewModel = fixture()
        let original = try render(viewModel)

        viewModel.mixResult = SIMD3(0.9, 0.1, 0.3)
        XCTAssertNotEqual(try render(viewModel), original, "The comparison must show the scored mix")

        viewModel.mixResult = SIMD3(0.2, 0.7, 0.4)
        viewModel.round = Round(
            request: ColorRequest(id: UUID(), text: "Changed target", targetSRGB: SIMD3(0.1, 0.2, 0.9)),
            colorModel: .ryb, assignments: [:], mix: Mix()
        )
        XCTAssertNotEqual(try render(viewModel), original, "The comparison must show the target")
    }

    func testScoreWithoutComparisonDataStillShowsPercentage() throws {
        let viewModel = fixture()
        let comparison = try render(viewModel)
        viewModel.mixResult = nil
        let scoreOnly = try render(viewModel)
        XCTAssertNotEqual(scoreOnly, comparison)

        viewModel.mixResult = SIMD3(0.2, 0.7, 0.4)
        viewModel.round = nil
        XCTAssertEqual(try render(viewModel), scoreOnly)
        XCTAssertNotEqual(scoreOnly, try render(ContentUnavailableView("No Score", systemImage: "number")))
    }

    func testMissingScoreShowsNoScoreEvenWhenComparisonDataExists() throws {
        let viewModel = fixture()
        let scored = try render(viewModel)
        viewModel.score = nil
        let fallback = try render(ContentUnavailableView("No Score", systemImage: "number"))
        XCTAssertEqual(try render(viewModel), fallback)
        XCTAssertNotEqual(scored, fallback)
    }

    private func fixture() -> GameViewModel {
        let viewModel = GameViewModel()
        viewModel.phase = .score
        viewModel.score = 87.65
        viewModel.round = Round(
            request: ColorData.requestPool[0], colorModel: .ryb,
            assignments: [:], mix: Mix()
        )
        viewModel.mixResult = SIMD3(0.2, 0.7, 0.4)
        return viewModel
    }

    private func render(_ viewModel: GameViewModel) throws -> Data {
        try render(ScoreView(viewModel: viewModel))
    }

    private func render<V: View>(_ view: V) throws -> Data {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
