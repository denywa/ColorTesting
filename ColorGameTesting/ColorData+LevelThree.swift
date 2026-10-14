import Foundation

extension ColorData {
    static let levelThreeRequests: [ColorRequest] = [
        // Blue
        ("Cornflower Blue", "I want the color of that little flower growing in fields of corn. Yes, darling, it has its own name!", "#6495ED"),
        ("Denim Blue", "Give me the color of my favorite jeans. The classic fabric everyone wears, not the black pair!", "#1560BD"),
        ("Steel Blue", "I want the color of a metal tool before anyone paints it. Strong, cool, and worthy of my face!", "#4682B4"),
        ("Navy Blue", "Give me the color of the uniform traditionally worn by sailors in the navy. I expect nothing less than nautical elegance!", "#000080"),
        ("Midnight Blue", "I want the color of the sky when the clock strikes twelve at night. The stars are out, and the world belongs to me!", "#191970"),
        // Red
        ("Maroon", "I want the color of the deep red fabric used in some traditional school uniforms. Not bright red, darling!", "#800000"),
        ("Carmine", "Give me the color of a pigment historically made from tiny cochineal insects. Yes, bugs can be fashionable too!", "#960018"),
        ("Cardinal Red", "I want the color of the feathers on the male bird named after a church official. Nature has excellent taste!", "#C41E3A"),
        ("Wine Red", "Give me the color of the drink made from fermented red grapes. Not the pale pink version, darling!", "#722F37"),
        ("Blood Red", "I want the color people associate with the liquid inside the human body. Keep it elegant; I am a work of art!", "#8A0303"),
        // Yellow
        ("Amber Yellow", "I want the color of ancient tree resin that hardened long ago and is sometimes made into jewelry. Not a gold ring!", "#FFBF00"),
        ("Cream Yellow", "Give me the pale yellow of a custard dessert before anyone burns the top. Sweet, smooth, and flawless!", "#FFFDD0"),
        ("Daffodil Yellow", "I want the color of the trumpet-shaped flower that appears in spring gardens. A flower fit for my hair!", "#FFFF31"),
        ("Maize Yellow", "Give me the color of the kernels on a cob before anyone turns them into popcorn. Focus on the kernels, darling!", "#FBEC5D"),
        ("Neon Yellow", "I want the glowing color of the pen people use to mark important words in their notes. My beauty deserves highlighting!", "#EFFF00"),
        // Green
        ("Kelly Green", "I want the bright green people wear to celebrate Ireland's patron saint in March. I expect festive perfection!", "#4CBB17"),
        ("Pistachio Green", "Give me the color of the soft inside of a pistachio nut. Not its shell, darling!", "#93C572"),
        ("Avocado Green", "I want the color of the flesh inside a ripe avocado after you cut it open. Ignore the dark skin!", "#B2C248"),
        ("Neon Green", "Give me the glowing green used on fluorescent safety clothing. I want to be visible from another dimension!", "#39FF14"),
        ("Fern Green", "I want the color of the feathery leaves on a fern. Not moss, darling—the plant with all those tiny leaflets!", "#4F7942"),
        // Pink
        ("Coral Pink", "I want the pink of tropical coral beneath the sea. Not the orange kind, darling, think pink!", "#F88379"),
        ("Flamingo Pink", "Give me the pink of the long-legged bird that stands in shallow water. White feathers are absolutely not my style!", "#FC8EAC"),
        ("Peony Pink", "I want the pink of that big, fluffy flower often used in wedding bouquets. Not a rose, darling!", "#E89BC7"),
        ("Strawberry Pink", "Give me the color of strawberry milk in a glass. Not chocolate milk, and not plain milk!", "#F2A7B5"),
        ("Cotton Candy Pink", "I want the color of the fluffy spun sugar sold at fairs. Sweet enough to match my personality!", "#FFBCD9"),
        // Purple
        ("Royal Purple", "I want the purple traditionally linked to emperors and kings. Make me look like the owner of this entire kingdom!", "#7851A9"),
        ("Wisteria", "Give me the color of those hanging flower clusters that drape down from a climbing vine. Very romantic, very me!", "#C9A0DC"),
        ("Iris Purple", "I want the purple of the flower named after a Greek goddess associated with rainbows. Mythology looks good on me!", "#5A4FCF"),
        ("Mulberry", "Give me the dark reddish-purple of the fruit that grows on a mulberry tree. Not grapes, darling!", "#70193D"),
        ("Heather Purple", "I want the purple of the tiny flowers that grow across open moorland. A whole hillside of them, just for my inspiration!", "#B7A0C7"),
        // Orange
        ("Neon Orange", "I want the glowing orange of the vest worn by road workers to stay visible. Safety first, fabulousness always!", "#FF5F1F"),
        ("Rust Orange", "Give me the reddish-orange that appears when iron sits in wet air for too long. Even oxidation has taste!", "#B7410E"),
        ("Copper Orange", "I want the shiny orange-brown of the metal used in some old coins and electrical wires. Not gold, darling!", "#B87333"),
        ("Salmon Orange", "Give me the orange-pink inside of a cooked salmon fillet. No carrots allowed in this kitchen!", "#FA8072"),
        ("Mandarin Orange", "I want the color of the peel of a small citrus fruit that is easy to divide into segments. Not a lemon, darling!", "#F37A16"),
        // Brown
        ("Mahogany", "I want the reddish-brown of the wood used to make fine furniture and musical instruments. Only premium materials for me!", "#4C2B21"),
        ("Sepia", "Give me the brown tone of an old photograph that looks like it came from another century. Vintage perfection!", "#704214"),
        ("Tan", "I want the light brown of natural leather before it is dyed a darker color. Simple, classic, and flawless!", "#D2B48C"),
        ("Toffe Brown", "Give me the brown of chewy candy made by heating sugar and butter. Not a chocolate bar, darling!", "#A16B4B"),
        ("Espresso Brown", "I want the nearly black-brown of a tiny, strong coffee served in a small cup. Intense, just like my personality!", "#3B2417")
    ].enumerated().map { index, entry in
        ColorRequest(id: UUID(uuidString: String(format: "C3000000-0000-0000-0000-%012X", index + 1))!,
                     text: entry.1, targetSRGB: ColorHex.sRGB(entry.2)!, difficulty: .level3)
    }
}
