import AppKit
import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class ContentViewTests: XCTestCase {
    func testAppRootInitiallyRendersSettingsScreen() throws {
        let appRoot = try renderedPixels(of: ContentView())
        let expectedSettings = try renderedPixels(of: SettingsView(viewModel: GameViewModel()))

        XCTAssertEqual(appRoot, expectedSettings,
                       "A new app window must show the color model settings screen")
    }

    private func renderedPixels<Content: View>(of content: Content) throws -> Data {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
