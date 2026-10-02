import XCTest
@testable import ColorGameTesting

final class ScaffoldTests: XCTestCase {
    func testScaffoldTypesAreAvailableToTheTestTarget() {
        let scaffoldTypes: [Any.Type] = [
            ColorModel.self,
            GameState.self,
            ColorRequest.self,
            GameViewModel.self,
            ColorMixer.self,
            ColorConverter.self,
            ScoreCalculator.self,
            KeyRouter.self,
            SettingsView.self,
            GameView.self,
            ResultView.self,
            ScoreView.self
        ]

        XCTAssertEqual(scaffoldTypes.count, 12)
    }
}
