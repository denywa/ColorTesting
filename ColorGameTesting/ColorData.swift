import Foundation

enum RequestDifficulty: Int, CaseIterable, Codable {
    case level1 = 1, level2 = 2, level3 = 3

    var title: String {
        switch self {
        case .level1: "Level 1 — Easy"
        case .level2: "Level 2 — Medium"
        case .level3: "Level 3 — Hard"
        }
    }
}

struct ColorRequest: Identifiable {
    let id: UUID
    let text: String
    let targetSRGB: SIMD3<Double>
    let difficulty: RequestDifficulty

    init(id: UUID, text: String, targetSRGB: SIMD3<Double>, difficulty: RequestDifficulty = .level1) {
        self.id = id
        self.text = text
        self.targetSRGB = targetSRGB
        self.difficulty = difficulty
    }
}

enum ColorData {
    static let rybPalette: [NamedColor] = [
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000001")!,
                   name: "Red", sRGB: SIMD3(1, 0, 0),
                   rybComponents: SIMD3(1, 0, 0)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
                   name: "Yellow", sRGB: SIMD3(1, 1, 0),
                   rybComponents: SIMD3(0, 1, 0)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000003")!,
                   name: "Blue", sRGB: SIMD3(0, 0, 1),
                   rybComponents: SIMD3(0, 0, 1)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000004")!,
                   name: "Black", sRGB: SIMD3(0, 0, 0),
                   rybComponents: SIMD3(1, 1, 1)),
        NamedColor(id: UUID(uuidString: "B0000000-0000-0000-0000-000000000005")!,
                   name: "White", sRGB: SIMD3(1, 1, 1),
                   rybComponents: SIMD3(0, 0, 0))
    ]

    static let requestPool: [ColorRequest] = [
        // Sky Blue — #87CEEB
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000001")!,
                     text: "I want the color of a clear blue summer sky. Make me look heavenly, darling!", targetSRGB: sRGB(hex: 0x87CEEB), difficulty: .level1),
        // Baby Blue — #89CFF0
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000002")!,
                     text: "Give me the soft blue of a baby's blanket. Cute, precious, and obviously expensive.", targetSRGB: sRGB(hex: 0x89CFF0), difficulty: .level1),
        // Powder Blue — #B0E0E6
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000003")!,
                     text: "I want the pale blue of a delicate porcelain teacup. Yes, my hair deserves fine dining.", targetSRGB: sRGB(hex: 0xB0E0E6), difficulty: .level1),
        // Ice Blue — #D6F1FF
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000004")!,
                     text: "Give me the color of blue ice in a freezer. Cold, flawless, and emotionally unavailable.", targetSRGB: sRGB(hex: 0xD6F1FF), difficulty: .level1),
        // Cyan — #5BC8D6
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000005")!,
                     text: "I want the bright blue of a swimming pool or clear sea water on a sunny day. Make a splash, please!", targetSRGB: sRGB(hex: 0x5BC8D6), difficulty: .level1),
        // Cherry Red — #D2042D
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000006")!,
                     text: "I want the color of ripe red cherries. Sweet, shiny, and dangerously gorgeous. Just like me!", targetSRGB: sRGB(hex: 0xD2042D), difficulty: .level1),
        // Scarlet — #FF2400
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000007")!,
                     text: "Give me the bright red of a superhero's cape. The world needs to notice my entrance.", targetSRGB: sRGB(hex: 0xFF2400), difficulty: .level1),
        // Crimson — #DC143C
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000008")!,
                     text: "I want the deep red of a velvet theater curtain. Drama is my birthright, darling.", targetSRGB: sRGB(hex: 0xDC143C), difficulty: .level1),
        // Burgundy — #800020
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000009")!,
                     text: "Give me the dark red of a fancy evening dress. I don't do cheap-looking entrances.", targetSRGB: sRGB(hex: 0x800020), difficulty: .level1),
        // Ruby Red — #E0115F
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000000A")!,
                     text: "I want the red of a ruby gemstone. Make me look like I belong in a royal treasure", targetSRGB: sRGB(hex: 0xE0115F), difficulty: .level1),
        // Lemon Yellow — #FFF44F
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000000B")!,
                     text: "I want the bright yellow of a lemon. Sour attitude, fabulous hair!", targetSRGB: sRGB(hex: 0xFFF44F), difficulty: .level1),
        // Sunshine Yellow — #FFD700
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000000C")!,
                     text: "Give me the bright yellow of sunshine pouring through a window. The world revolves around me!", targetSRGB: sRGB(hex: 0xFFD700), difficulty: .level1),
        // Mustard Yellow — #FFDB58
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000000D")!,
                     text: "I want the yellow of mustard sauce. Bold, spicy, and impossible to ignore.", targetSRGB: sRGB(hex: 0xFFDB58), difficulty: .level1),
        // Golden Yellow — #FFCC33
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000000E")!,
                     text: "Give me the color of shiny gold jewelry. I expect nothing less than royal treatment.", targetSRGB: sRGB(hex: 0xFFCC33), difficulty: .level1),
        // Butter Yellow — #FFF1A8
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000000F")!,
                     text: "I want the soft yellow of a stick of butter. Smooth, rich, and ready for the spotlight.", targetSRGB: sRGB(hex: 0xFFF1A8), difficulty: .level1),
        // Mint Green — #98FF98
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000010")!,
                     text: "I want the fresh green of mint leaves in a cold drink. Refreshing, just like my presence!", targetSRGB: sRGB(hex: 0x98FF98), difficulty: .level1),
        // Lime Green — #BFFF00
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000011")!,
                     text: "Give me the bright green of a lime peel. Sour face, sweet style!", targetSRGB: sRGB(hex: 0xBFFF00), difficulty: .level1),
        // Forest Green — #228B22
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000012")!,
                     text: "I want the deep green of a thick forest. I own the trees now, darling.", targetSRGB: sRGB(hex: 0x228B22), difficulty: .level1),
        // Olive Green — #808000
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000013")!,
                     text: "Give me the muted green of green olives. Mediterranean luxury, obviously.", targetSRGB: sRGB(hex: 0x808000), difficulty: .level1),
        // Sage Green — #9CAF88
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000014")!,
                     text: "I want the soft, dusty green of sage leaves. Calm, elegant, and far above the drama.", targetSRGB: sRGB(hex: 0x9CAF88), difficulty: .level1),
        // Bubblegum Pink — #FF85C2
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000015")!,
                     text: "I want the bright pink of bubblegum. Sweet, loud, and impossible to ignore. Like me!", targetSRGB: sRGB(hex: 0xFF85C2), difficulty: .level1),
        // Blush Pink — #F4C2C2
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000016")!,
                     text: "Give me the soft pink of cheeks after a tiny compliment. I'm naturally adorable, darling.", targetSRGB: sRGB(hex: 0xF4C2C2), difficulty: .level1),
        // Hot Pink — #FF69B4
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000017")!,
                     text: "I want a loud, intense pink. If people can ignore me, you have failed.", targetSRGB: sRGB(hex: 0xFF69B4), difficulty: .level1),
        // Dusty Pink — #D8A0A6
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000018")!,
                     text: "Give me the muted pink of an old rose. Vintage, elegant, and still better than everyone.", targetSRGB: sRGB(hex: 0xD8A0A6), difficulty: .level1),
        // Pastel Pink — #FFD1DC
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000019")!,
                     text: "I want a pale, gentle pink, like a pastel birthday decoration. Cute is my natural state.", targetSRGB: sRGB(hex: 0xFFD1DC), difficulty: .level1),
        // Lavender — #C8B4F4
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000001A")!,
                     text: "I want the pale purple of lavender flowers. Relaxing, elegant, and expensive-smelling.", targetSRGB: sRGB(hex: 0xC8B4F4), difficulty: .level1),
        // Violet — #8F00FF
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000001B")!,
                     text: "Give me the vivid purple of a violet flower. Small flower, enormous personality. Just like me!", targetSRGB: sRGB(hex: 0x8F00FF), difficulty: .level1),
        // Grape Purple — #6F2DA8
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000001C")!,
                     text: "I want the rich purple of purple grapes. Fruit royalty has arrived!", targetSRGB: sRGB(hex: 0x6F2DA8), difficulty: .level1),
        // Plum Purple — #673147
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000001D")!,
                     text: "Give me the dark purple skin of a ripe plum. Sweet, mysterious, and very exclusive.", targetSRGB: sRGB(hex: 0x673147), difficulty: .level1),
        // Lilac — #C8A2C8
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000001E")!,
                     text: "I want the light purple of lilac blossoms. Delicate, darling, but never forgettable.", targetSRGB: sRGB(hex: 0xC8A2C8), difficulty: .level1),
        // Carrot Orange — #ED9121
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-00000000001F")!,
                     text: "I want the bright orange of a carrot. Bugs Bunny could never wear it this well!", targetSRGB: sRGB(hex: 0xED9121), difficulty: .level1),
        // Peach — #FFCBA4
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000020")!,
                     text: "Give me the soft orange-pink of a ripe peach. Sweet, fuzzy, and fabulous.", targetSRGB: sRGB(hex: 0xFFCBA4), difficulty: .level1),
        // Tangerine — #F28500
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000021")!,
                     text: "I want the bright orange of a tangerine peel. Citrus energy, premium attitude!", targetSRGB: sRGB(hex: 0xF28500), difficulty: .level1),
        // Burnt Orange — #CC5500
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000022")!,
                     text: "Give me the deep orange of autumn leaves. Warm, dramatic, and impossible to replace.", targetSRGB: sRGB(hex: 0xCC5500), difficulty: .level1),
        // Apricot — #FBCEB1
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000023")!,
                     text: "I want the soft orange of an apricot fruit. Delicate, juicy, and naturally superior.", targetSRGB: sRGB(hex: 0xFBCEB1), difficulty: .level1),
        // Dark Chocolate — #3B1F16
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000024")!,
                     text: "I want the dark brown of a chocolate bar with very little milk. Bitter, rich, and expensive. Like my standards!", targetSRGB: sRGB(hex: 0x3B1F16), difficulty: .level1),
        // Caramel Brown — #AF6F3C
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000025")!,
                     text: "Give me the warm brown of melted caramel. Sweet, smooth, and impossible to resist.", targetSRGB: sRGB(hex: 0xAF6F3C), difficulty: .level1),
        // Chestnut Brown — #954535
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000026")!,
                     text: "I want the rich brown of a chestnut shell. Autumn elegance, darling!", targetSRGB: sRGB(hex: 0x954535), difficulty: .level1),
        // Beige — #D9C3A5
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000027")!,
                     text: "Give me the pale brown of sand on a quiet beach. Neutral, classy, and never boring when I wear it.", targetSRGB: sRGB(hex: 0xD9C3A5), difficulty: .level1),
        // Taupe — #8B7E74
        ColorRequest(id: UUID(uuidString: "C1000000-0000-0000-0000-000000000028")!,
                     text: "I want the grayish brown of a taupe sofa. Interior design has finally found its muse.", targetSRGB: sRGB(hex: 0x8B7E74), difficulty: .level1),
        // Level 2: Blue
        // Turquoise — #40E0D0
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000001")!,
                     text: "Give me the color of tropical water around a sunny island. Well, I deserve a private beach.", targetSRGB: sRGB(hex: 0x40E0D0), difficulty: .level2),
        // Teal Blue — #008080
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000002")!,
                     text: "I want the color on a teal duck's head. Nature clearly designed it for someone as fabulous as me.", targetSRGB: sRGB(hex: 0x008080), difficulty: .level2),
        // Ocean Blue — #005B96
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000003")!,
                     text: "Give me the color of the sea far below the surface, where sunlight barely reaches. Mysterious, just like my beauty!", targetSRGB: sRGB(hex: 0x005B96), difficulty: .level2),
        // Royal Blue — #4169E1
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000004")!,
                     text: "I want the bold blue associated with royal robes and grand ceremonies. Make me look ready to take the throne!", targetSRGB: sRGB(hex: 0x4169E1), difficulty: .level2),
        // Blue ink pen — #1A43BF
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000005")!,
                     text: "Honey, give me the color of the ink inside a classic blue ballpoint pen. You know, the one you borrow and NEVER return!", targetSRGB: sRGB(hex: 0x1A43BF), difficulty: .level2),
        // Level 2: Red
        // Tomato Red — #FF6347
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000006")!,
                     text: "I want the color of the fruit people slice for burgers and salads. Round, juicy, and obviously iconic!", targetSRGB: sRGB(hex: 0xFF6347), difficulty: .level2),
        // Brick Red — #B55239
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000007")!,
                     text: "Give me the color of traditional clay bricks used to build house walls. Not painted bricks, darling. The classic ones straight from the construction site!", targetSRGB: sRGB(hex: 0xB55239), difficulty: .level2),
        // Rust Red — #B7410E
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000008")!,
                     text: "I want the color that appears on iron left outside in the rain for too long. Even old metal has style!", targetSRGB: sRGB(hex: 0xB7410E), difficulty: .level2),
        // Rose Red — #C21E56
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000009")!,
                     text: "Darling, I want the classic rose from a romantic date. The one with velvety petals that people give when they say ‘I love you.’ A whole bouquet of them, please!", targetSRGB: sRGB(hex: 0xC21E56), difficulty: .level2),
        // Chili Red — #D62828
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-00000000000A")!,
                     text: "Give me the color of a fully ripe chili pepper. The spicy little diva that turns your favorite sambal into a fiery masterpiece!", targetSRGB: sRGB(hex: 0xD62828), difficulty: .level2),
        // Level 2: Yellow
        // Honey Yellow — #DDAF26
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-00000000000B")!,
                     text: "Give me the color of the sweet liquid made by bees and stored in a jar. Nature's luxury product!", targetSRGB: sRGB(hex: 0xDDAF26), difficulty: .level2),
        // Banana Yellow — #FFE135
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-00000000000C")!,
                     text: "I want the color of a ripe fruit monkeys love. Not green, not brown. The perfect snack!", targetSRGB: sRGB(hex: 0xFFE135), difficulty: .level2),
        // Sponge Cake Yellow — #F4D35E
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-00000000000D")!,
                     text: "Give me the color of the inside of a freshly baked sponge cake. That sunny, fluffy center that makes every tea party fabulous!", targetSRGB: sRGB(hex: 0xF4D35E), difficulty: .level2),
        // Golden Yellow — #FFC000
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-00000000000E")!,
                     text: "Sweetheart, give me the golden color of a shiny gold coin. Rich, bright, and expensive-looking. Naturally, just like me!", targetSRGB: sRGB(hex: 0xFFC000), difficulty: .level2),
        // Vanilla Yellow — #F3E5AB
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-00000000000F")!,
                     text: "Give me the soft, creamy color of vanilla pudding. Smooth, sweet, and delicate enough for my royal taste!", targetSRGB: sRGB(hex: 0xF3E5AB), difficulty: .level2),
        // Level 2: Green
        // Moss Green — #8A9A5B
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000010")!,
                     text: "I want the color of the soft growth that covers damp stones and tree trunks. Woodland chic, darling!", targetSRGB: sRGB(hex: 0x8A9A5B), difficulty: .level2),
        // Jade Green — #00A86B
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000011")!,
                     text: "I want the color of the polished green stone used to make bracelets and carved ornaments. Ancient treasure, modern diva!", targetSRGB: sRGB(hex: 0x00A86B), difficulty: .level2),
        // Hunter Green — #355E3B
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000012")!,
                     text: "Give me the dark green associated with traditional outdoor jackets and forest clothing. Rugged, but still runway-ready!", targetSRGB: sRGB(hex: 0x355E3B), difficulty: .level2),
        // Matcha Latte — #A8B876
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000013")!,
                     text: "Make it like my matcha latte order. Extra fancy, perfectly whisked, and absolutely NOT the cheap stuff!", targetSRGB: sRGB(hex: 0xA8B876), difficulty: .level2),
        // Mint Ice Cream — #B7E4C7
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000014")!,
                     text: "One scoop of mint ice cream, please! Cool, creamy, and expensive-looking. Unlike my last situationship.", targetSRGB: sRGB(hex: 0xB7E4C7), difficulty: .level2),
        // Level 2: Orange and Brown
        // Pumpkin Orange — #FF7518
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000015")!,
                     text: "Give me the color of the big round fruit people carve into spooky faces for Halloween. Scary? Only my beauty!", targetSRGB: sRGB(hex: 0xFF7518), difficulty: .level2),
        // Cocoa Brown — #6F4E37
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000016")!,
                     text: "I want the brown powder people use to make chocolate desserts. Sweetness is optional, darling!", targetSRGB: sRGB(hex: 0x6F4E37), difficulty: .level2),
        // Mocha — #967969
        ColorRequest(id: UUID(uuidString: "C2000000-0000-0000-0000-000000000017")!,
                     text: "Give me the color inspired by a drink made with coffee and chocolate together. Two classics, one flawless customer!", targetSRGB: sRGB(hex: 0x967969), difficulty: .level2)
    ] + levelThreeRequests

    private static func sRGB(hex: UInt32) -> SIMD3<Double> {
        SIMD3(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    static func colors(for model: ColorModel) -> [NamedColor] {
        switch model {
        case .ryb: return rybPalette
        }
    }
}
