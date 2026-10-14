import XCTest
@testable import ColorGameTesting

final class LevelThreeColorRequestTests: XCTestCase {
    func testLevelThreeCatalogHasFortyDistinctTargetsAndExactPrompts() {
        let requests = ColorData.levelThreeRequests
        XCTAssertEqual(requests.count, 40)
        XCTAssertEqual(Set(requests.map(\.id)).count, 40)
        XCTAssertEqual(Set(requests.map(\.text)).count, 40)
        XCTAssertTrue(requests.allSatisfy { $0.difficulty == .level3 })
        XCTAssertTrue(requests.allSatisfy { request in
            ColorData.requestPool.contains { $0.id == request.id }
        })
        XCTAssertEqual(requests.first?.text, "I want the color of that little flower growing in fields of corn. Yes, darling, it has its own name!")
        XCTAssertEqual(ColorHex.string(from: requests.first!.targetSRGB), "#6495ED")
        XCTAssertEqual(requests.last?.text, "I want the nearly black-brown of a tiny, strong coffee served in a small cup. Intense, just like my personality!")
        XCTAssertEqual(ColorHex.string(from: requests.last!.targetSRGB), "#3B2417")
    }
}
