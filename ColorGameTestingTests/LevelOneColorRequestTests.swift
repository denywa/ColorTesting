import Foundation
import XCTest
@testable import ColorGameTesting

final class LevelOneColorRequestTests: XCTestCase {
    private let fixtures: [(prompt: String, hex: String, units: [Int], score: Double)] = [
        // Sky Blue
        ("I want the color of a clear blue summer sky. Make me look heavenly, darling!", "#87CEEB", [0, 4, 10, 0, 15], 94.033725753124),
        // Baby Blue
        ("Give me the soft blue of a baby's blanket. Cute, precious, and obviously expensive.", "#89CFF0", [0, 2, 5, 0, 8], 93.727991159366),
        // Powder Blue
        ("I want the pale blue of a delicate porcelain teacup. Yes, my hair deserves fine dining.", "#B0E0E6", [0, 1, 2, 0, 5], 96.195973978475),
        // Ice Blue
        ("Give me the color of blue ice in a freezer. Cold, flawless, and emotionally unavailable.", "#D6F1FF", [0, 2, 5, 0, 23], 96.900566247998),
        // Cyan
        ("I want the bright blue of a swimming pool or clear sea water on a sunny day. Make a splash, please!", "#5BC8D6", [0, 5, 11, 0, 11], 91.539335288499),
        // Cherry Red
        ("I want the color of ripe red cherries. Sweet, shiny, and dangerously gorgeous. Just like me!", "#D2042D", [15, 0, 2, 2, 0], 99.851801199228),
        // Scarlet
        ("Give me the bright red of a superhero's cape. The world needs to notice my entrance.", "#FF2400", [7, 1, 0, 0, 0], 99.481663285029),
        // Crimson
        ("I want the deep red of a velvet theater curtain. Drama is my birthright, darling.", "#DC143C", [24, 1, 4, 0, 1], 99.822090021616),
        // Burgundy
        ("Give me the dark red of a fancy evening dress. I don't do cheap-looking entrances.", "#800020", [13, 0, 2, 12, 0], 99.660715021251),
        // Ruby Red
        ("I want the red of a ruby gemstone. Make me look like I belong in a royal treasure", "#E0115F", [20, 0, 5, 0, 1], 99.758953858804),
        // Lemon Yellow
        ("I want the bright yellow of a lemon. Sour attitude, fabulous hair!", "#FFF44F", [2, 17, 0, 0, 7], 99.847661012766),
        // Sunshine Yellow
        ("Give me the bright yellow of sunshine pouring through a window. The world revolves around me!", "#FFD700", [7, 19, 0, 0, 0], 99.246126812812),
        // Mustard Yellow
        ("I want the yellow of mustard sauce. Bold, spicy, and impossible to ignore.", "#FFDB58", [7, 15, 0, 0, 6], 99.452568618920),
        // Golden Yellow
        ("Give me the color of shiny gold jewelry. I expect nothing less than royal treatment.", "#FFCC33", [8, 14, 0, 0, 1], 99.216191885211),
        // Butter Yellow
        ("I want the soft yellow of a stick of butter. Smooth, rich, and ready for the spotlight.", "#FFF1A8", [1, 3, 0, 0, 6], 99.746264243610),
        // Mint Green
        ("I want the fresh green of mint leaves in a cold drink. Refreshing, just like my presence!", "#98FF98", [0, 9, 8, 0, 12], 95.211971262883),
        // Lime Green
        ("Give me the bright green of a lime peel. Sour face, sweet style!", "#BFFF00", [0, 21, 5, 0, 1], 97.389925794751),
        // Forest Green
        ("I want the deep green of a thick forest. I own the trees now, darling.", "#228B22", [0, 10, 10, 9, 0], 98.516291519730),
        // Olive Green
        ("Give me the muted green of green olives. Mediterranean luxury, obviously.", "#808000", [0, 1, 0, 1, 0], 99.902467368022),
        // Sage Green
        ("I want the soft, dusty green of sage leaves. Calm, elegant, and far above the drama.", "#9CAF88", [0, 3, 2, 6, 11], 99.708349557717),
        // Bubblegum Pink
        ("I want the bright pink of bubblegum. Sweet, loud, and impossible to ignore. Like me!", "#FF85C2", [11, 0, 4, 0, 14], 98.032823743805),
        // Blush Pink
        ("Give me the soft pink of cheeks after a tiny compliment. I'm naturally adorable, darling.", "#F4C2C2", [5, 0, 0, 1, 19], 99.880026495212),
        // Hot Pink
        ("I want a loud, intense pink. If people can ignore me, you have failed.", "#FF69B4", [9, 0, 3, 0, 8], 97.760647302708),
        // Dusty Pink
        ("Give me the muted pink of an old rose. Vintage, elegant, and still better than everyone.", "#D8A0A6", [4, 1, 1, 0, 8], 98.848459474848),
        // Pastel Pink
        ("I want a pale, gentle pink, like a pastel birthday decoration. Cute is my natural state.", "#FFD1DC", [5, 0, 1, 0, 24], 99.430964204517),
        // Lavender
        ("I want the pale purple of lavender flowers. Relaxing, elegant, and expensive-smelling.", "#C8B4F4", [2, 0, 6, 1, 19], 99.695499055639),
        // Violet
        ("Give me the vivid purple of a violet flower. Small flower, enormous personality. Just like me!", "#8F00FF", [10, 0, 16, 0, 1], 98.428831923362),
        // Grape Purple
        ("I want the rich purple of purple grapes. Fruit royalty has arrived!", "#6F2DA8", [6, 0, 9, 6, 2], 99.793778017281),
        // Plum Purple
        ("Give me the dark purple skin of a ripe plum. Sweet, mysterious, and very exclusive.", "#673147", [7, 1, 3, 14, 4], 99.428561841350),
        // Lilac
        ("I want the light purple of lilac blossoms. Delicate, darling, but never forgettable.", "#C8A2C8", [5, 1, 4, 2, 16], 99.843715284155),
        // Carrot Orange
        ("I want the bright orange of a carrot. Bugs Bunny could never wear it this well!", "#ED9121", [13, 10, 0, 1, 0], 99.216300884950),
        // Peach
        ("Give me the soft orange-pink of a ripe peach. Sweet, fuzzy, and fabulous.", "#FFCBA4", [5, 3, 0, 0, 10], 99.627116864884),
        // Tangerine
        ("I want the bright orange of a tangerine peel. Citrus energy, premium attitude!", "#F28500", [16, 11, 0, 1, 0], 98.507292982328),
        // Burnt Orange
        ("Give me the deep orange of autumn leaves. Warm, dramatic, and impossible to replace.", "#CC5500", [15, 7, 0, 5, 0], 98.653965349729),
        // Apricot
        ("I want the soft orange of an apricot fruit. Delicate, juicy, and naturally superior.", "#FBCEB1", [6, 3, 0, 0, 16], 99.640584461999),
        // Dark Chocolate
        ("I want the dark brown of a chocolate bar with very little milk. Bitter, rich, and expensive. Like my standards!", "#3B1F16", [5, 3, 2, 14, 0], 99.544901489000),
        // Caramel Brown
        ("Give me the warm brown of melted caramel. Sweet, smooth, and impossible to resist.", "#AF6F3C", [11, 8, 3, 0, 0], 99.802417277047),
        // Chestnut Brown
        ("I want the rich brown of a chestnut shell. Autumn elegance, darling!", "#954535", [10, 2, 0, 12, 5], 99.852687921333),
        // Beige
        ("Give me the pale brown of sand on a quiet beach. Neutral, classy, and never boring when I wear it.", "#D9C3A5", [5, 4, 0, 4, 17], 99.156386700084),
        // Taupe
        ("I want the grayish brown of a taupe sofa. Interior design has finally found its muse.", "#8B7E74", [3, 2, 1, 11, 12], 99.423899335240),
    ]

    func testSuppliedPromptsHaveExactTargetsUniqueIDsAndLevelOne() {
        XCTAssertGreaterThanOrEqual(ColorData.requestPool.count, 47)
        XCTAssertEqual(Set(ColorData.requestPool.map(\.id)).count, ColorData.requestPool.count)
        let requests = ColorData.requestPool.filter { $0.id.uuidString.hasPrefix("C1000000-") }
        XCTAssertEqual(requests.count, fixtures.count)
        for (index, pair) in zip(requests, fixtures).enumerated() {
            let (request, fixture) = pair
            XCTAssertEqual(request.id, UUID(uuidString: String(format: "C1000000-0000-0000-0000-%012X", index + 1)))
            XCTAssertEqual(request.text, fixture.prompt)
            XCTAssertEqual(ColorHex.string(from: request.targetSRGB), fixture.hex)
            XCTAssertEqual(request.difficulty, .level1)
        }
    }

    func testAnswerKeyRecipesMatchDocumentedScoresAndPassDefaultThreshold() {
        for (request, fixture) in zip(ColorData.requestPool.filter { $0.id.uuidString.hasPrefix("C1000000-") }, fixtures) {
            XCTAssertEqual(fixture.units.count, 5)
            XCTAssertTrue(fixture.units.allSatisfy { $0 >= 0 })
            XCTAssertTrue((1...30).contains(fixture.units.reduce(0, +)))
            let units = zip(ColorData.rybPalette, fixture.units).flatMap { color, count in
                Array(repeating: ColorUnit(color: color), count: count)
            }
            let mixed = ColorMixer.blend(units, model: .ryb)
            let score = ScoreCalculator.matchPercentage(ColorConverter.sRGBToLab(mixed),
                                                        ColorConverter.sRGBToLab(request.targetSRGB))
            XCTAssertEqual(score, fixture.score, accuracy: 0.005, fixture.prompt)
            XCTAssertGreaterThanOrEqual(score, EndlessRunConfiguration().passingScore, fixture.prompt)
        }
    }
}
