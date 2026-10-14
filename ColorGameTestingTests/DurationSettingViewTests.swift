import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class DurationSettingViewTests: XCTestCase {
    func testMinuteAndSecondEditsPreserveTheOtherComponent() {
        var duration = 600
        let view = DurationSettingView(title: "Day Time", totalSeconds: Binding(
            get: { duration }, set: { duration = $0 }
        ))
        view.seconds.wrappedValue = 17
        view.minutes.wrappedValue = 2
        XCTAssertEqual(duration, 137)
        view.minutes.wrappedValue = 0
        XCTAssertEqual(duration, 17)
        view.seconds.wrappedValue = 1
        XCTAssertEqual(duration, 1)
    }

    func testFieldsKeepDurationsWithinSupportedLimits() {
        for maximum in [3600, 86_400] {
            var duration = 45
            let view = DurationSettingView(title: "Duration", totalSeconds: Binding(
                get: { duration }, set: { duration = $0 }
            ), maximumSeconds: maximum)
            view.seconds.wrappedValue = Int.max
            XCTAssertEqual(duration, 59)
            view.minutes.wrappedValue = Int.max
            XCTAssertEqual(duration, maximum)
            view.minutes.wrappedValue = Int.min
            XCTAssertEqual(duration, 1)
            view.seconds.wrappedValue = Int.min
            XCTAssertEqual(duration, 1)
        }
    }
}
