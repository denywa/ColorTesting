import AppKit
import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class ModeSelectionViewTests: XCTestCase {
    func testBothModeButtonsRenderAndSelectTheirModes() throws {
        var selectedModes: [PlayMode] = []
        let view = ModeSelectionView { selectedModes.append($0) }
        let buttons = buttons(in: view.body)

        XCTAssertEqual(buttons.count, 2)
        XCTAssertTrue(buttons.contains { String(describing: label(of: $0)).contains("Three players on one device") })
        XCTAssertTrue(buttons.contains { String(describing: label(of: $0)).contains("Three devices on local Wi-Fi") })

        try press(buttons, labeled: "Three players on one device")
        try press(buttons, labeled: "Three devices on local Wi-Fi")
        XCTAssertEqual(selectedModes, [.singleDevice, .threeDevices])

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        hostingView.layoutSubtreeIfNeeded()
        XCTAssertNotNil(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
    }

    private func buttons(in value: Any) -> [Button<Text>] {
        if let button = value as? Button<Text> { return [button] }
        return Mirror(reflecting: value).children.flatMap { buttons(in: $0.value) }
    }

    private func label(of button: Button<Text>) -> Text {
        Mirror(reflecting: button).children.first { $0.label == "label" }!.value as! Text
    }

    private func press(_ buttons: [Button<Text>], labeled title: String) throws {
        let button = try XCTUnwrap(buttons.first { String(describing: label(of: $0)).contains(title) })
        let action = try XCTUnwrap(Mirror(reflecting: button).children.first { $0.label == "action" }?.value)
        let closure = try XCTUnwrap(Mirror(reflecting: action).children.first?.value as? @MainActor () -> Void)
        closure()
    }
}
