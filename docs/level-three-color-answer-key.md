# Level 3 Color Requests — Targets and Answer Key

These are selected gameplay target colors, not a claim that every color name has one universal hex definition. All 40 supplied prompts are added to Level 3.

## Reading the recipes

- Counts are units (color taps), in the order Red, Yellow, Blue, Black, White. Zero means do not add that color.
- Recipes use the current `ColorMixer`, `ColorConverter`, and `ScoreCalculator` implementations for both Manual and Auto Mix.
- The search evaluated every non-empty integer combination with **at most 20 total units**: 53,129 candidates per target. The recipe minimizes Delta E 2000 within this limit; exact ties prefer fewer units.
- Scores use the unrounded mixed RGB values. The displayed mixed hex is rounded to 8-bit RGB for reference, so calculating from that hex alone can differ slightly.
- All listed recipes exceed the default 70% passing threshold. They are bounded-search results, not a proof of the closest possible mixture with unlimited units.
- Apply/Finish after adding the listed quantities. Player color assignments and reassignment timing determine who can contribute each ingredient.

## Target colors and closest recipes

### Blue

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Cornflower Blue | `#6495ED` | 0 | 3 | 10 | 0 | 7 | 20 | `#7695C5` | 97.25% |
| Denim Blue | `#1560BD` | 0 | 4 | 14 | 0 | 1 | 19 | `#3662AD` | 98.69% |
| Steel Blue | `#4682B4` | 0 | 4 | 11 | 0 | 3 | 18 | `#5583A8` | 98.63% |
| Navy Blue | `#000080` | 0 | 0 | 1 | 1 | 0 | 2 | `#000080` | 99.96% |
| Midnight Blue | `#191970` | 1 | 1 | 4 | 3 | 0 | 9 | `#19196E` | 99.81% |

### Red

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Maroon | `#800000` | 1 | 0 | 0 | 1 | 0 | 2 | `#800000` | 99.95% |
| Carmine | `#960018` | 10 | 0 | 1 | 7 | 0 | 18 | `#930518` | 99.67% |
| Cardinal Red | `#C41E3A` | 8 | 0 | 1 | 2 | 1 | 12 | `#C71C3A` | 99.77% |
| Wine Red | `#722F37` | 8 | 4 | 4 | 1 | 0 | 17 | `#703434` | 98.45% |
| Blood Red | `#8A0303` | 7 | 0 | 0 | 6 | 0 | 13 | `#890000` | 99.78% |

### Yellow

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Amber Yellow | `#FFBF00` | 7 | 10 | 0 | 0 | 0 | 17 | `#F5BF32` | 98.61% |
| Cream Yellow | `#FFFDD0` | 0 | 3 | 0 | 0 | 14 | 17 | `#FFFFD2` | 99.63% |
| Daffodil Yellow | `#FFFF31` | 0 | 13 | 0 | 0 | 3 | 16 | `#FFFF30` | 99.97% |
| Maize Yellow | `#FBEC5D` | 2 | 9 | 0 | 0 | 5 | 16 | `#FCEC5F` | 99.79% |
| Neon Yellow | `#EFFF00` | 0 | 18 | 1 | 0 | 0 | 19 | `#EEF906` | 99.33% |

### Green

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Kelly Green | `#4CBB17` | 0 | 7 | 7 | 1 | 0 | 15 | `#5ABB38` | 98.76% |
| Pistachio Green | `#93C572` | 1 | 6 | 5 | 0 | 5 | 17 | `#94C574` | 99.80% |
| Avocado Green | `#B2C248` | 1 | 8 | 2 | 1 | 3 | 15 | `#B5C24A` | 99.74% |
| Neon Green | `#39FF14` | 0 | 10 | 6 | 0 | 1 | 17 | `#8FD839` | 91.12% |
| Fern Green | `#4F7942` | 1 | 4 | 4 | 5 | 2 | 16 | `#527944` | 99.64% |

### Pink

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Coral Pink | `#F88379` | 10 | 1 | 0 | 0 | 9 | 20 | `#FE8479` | 99.43% |
| Flamingo Pink | `#FC8EAC` | 5 | 0 | 1 | 0 | 7 | 13 | `#F290AB` | 99.14% |
| Peony Pink | `#E89BC7` | 5 | 0 | 2 | 0 | 9 | 16 | `#EA9AC6` | 99.73% |
| Strawberry Pink | `#F2A7B5` | 6 | 0 | 1 | 0 | 13 | 20 | `#F7AABC` | 99.23% |
| Cotton Candy Pink | `#FFBCD9` | 3 | 0 | 1 | 0 | 9 | 13 | `#F2B7D2` | 98.86% |

### Purple

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Royal Purple | `#7851A9` | 3 | 1 | 5 | 2 | 3 | 14 | `#7752AA` | 99.78% |
| Wisteria | `#C9A0DC` | 3 | 0 | 3 | 2 | 11 | 19 | `#CAA1D9` | 99.56% |
| Iris Purple | `#5A4FCF` | 2 | 1 | 11 | 1 | 5 | 20 | `#5C4FD4` | 99.64% |
| Mulberry | `#70193D` | 7 | 0 | 2 | 10 | 1 | 20 | `#6F1539` | 99.45% |
| Heather Purple | `#B7A0C7` | 3 | 1 | 3 | 2 | 11 | 20 | `#BAA0C3` | 99.29% |

### Orange

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Neon Orange | `#FF5F1F` | 8 | 3 | 0 | 0 | 0 | 11 | `#F86121` | 99.45% |
| Rust Orange | `#B7410E` | 8 | 3 | 0 | 4 | 0 | 15 | `#B64718` | 99.33% |
| Copper Orange | `#B87333` | 8 | 6 | 1 | 2 | 0 | 17 | `#BA7531` | 99.42% |
| Salmon Orange | `#FA8072` | 9 | 1 | 0 | 0 | 7 | 17 | `#FE7E70` | 99.63% |
| Mandarin Orange | `#F37A16` | 12 | 7 | 0 | 1 | 0 | 20 | `#EA7C2B` | 98.92% |

### Brown

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Mahogany | `#4C2B21` | 3 | 1 | 0 | 14 | 2 | 20 | `#4B2B20` | 99.54% |
| Sepia | `#704214` | 3 | 2 | 0 | 6 | 0 | 11 | `#704016` | 99.40% |
| Tan | `#D2B48C` | 5 | 4 | 1 | 1 | 9 | 20 | `#D3B390` | 98.89% |
| Toffe Brown | `#A16B4B` | 4 | 2 | 0 | 5 | 3 | 14 | `#A16948` | 99.65% |
| Espresso Brown | `#3B2417` | 2 | 1 | 0 | 13 | 1 | 17 | `#3B2416` | 99.80% |

## Exact request text

### Cornflower Blue — #6495ED

I want the color of that little flower growing in fields of corn. Yes, darling, it has its own name!

### Denim Blue — #1560BD

Give me the color of my favorite jeans. The classic fabric everyone wears, not the black pair!

### Steel Blue — #4682B4

I want the color of a metal tool before anyone paints it. Strong, cool, and worthy of my face!

### Navy Blue — #000080

Give me the color of the uniform traditionally worn by sailors in the navy. I expect nothing less than nautical elegance!

### Midnight Blue — #191970

I want the color of the sky when the clock strikes twelve at night. The stars are out, and the world belongs to me!

### Maroon — #800000

I want the color of the deep red fabric used in some traditional school uniforms. Not bright red, darling!

### Carmine — #960018

Give me the color of a pigment historically made from tiny cochineal insects. Yes, bugs can be fashionable too!

### Cardinal Red — #C41E3A

I want the color of the feathers on the male bird named after a church official. Nature has excellent taste!

### Wine Red — #722F37

Give me the color of the drink made from fermented red grapes. Not the pale pink version, darling!

### Blood Red — #8A0303

I want the color people associate with the liquid inside the human body. Keep it elegant; I am a work of art!

### Amber Yellow — #FFBF00

I want the color of ancient tree resin that hardened long ago and is sometimes made into jewelry. Not a gold ring!

### Cream Yellow — #FFFDD0

Give me the pale yellow of a custard dessert before anyone burns the top. Sweet, smooth, and flawless!

### Daffodil Yellow — #FFFF31

I want the color of the trumpet-shaped flower that appears in spring gardens. A flower fit for my hair!

### Maize Yellow — #FBEC5D

Give me the color of the kernels on a cob before anyone turns them into popcorn. Focus on the kernels, darling!

### Neon Yellow — #EFFF00

I want the glowing color of the pen people use to mark important words in their notes. My beauty deserves highlighting!

### Kelly Green — #4CBB17

I want the bright green people wear to celebrate Ireland's patron saint in March. I expect festive perfection!

### Pistachio Green — #93C572

Give me the color of the soft inside of a pistachio nut. Not its shell, darling!

### Avocado Green — #B2C248

I want the color of the flesh inside a ripe avocado after you cut it open. Ignore the dark skin!

### Neon Green — #39FF14

Give me the glowing green used on fluorescent safety clothing. I want to be visible from another dimension!

### Fern Green — #4F7942

I want the color of the feathery leaves on a fern. Not moss, darling—the plant with all those tiny leaflets!

### Coral Pink — #F88379

I want the pink of tropical coral beneath the sea. Not the orange kind, darling, think pink!

### Flamingo Pink — #FC8EAC

Give me the pink of the long-legged bird that stands in shallow water. White feathers are absolutely not my style!

### Peony Pink — #E89BC7

I want the pink of that big, fluffy flower often used in wedding bouquets. Not a rose, darling!

### Strawberry Pink — #F2A7B5

Give me the color of strawberry milk in a glass. Not chocolate milk, and not plain milk!

### Cotton Candy Pink — #FFBCD9

I want the color of the fluffy spun sugar sold at fairs. Sweet enough to match my personality!

### Royal Purple — #7851A9

I want the purple traditionally linked to emperors and kings. Make me look like the owner of this entire kingdom!

### Wisteria — #C9A0DC

Give me the color of those hanging flower clusters that drape down from a climbing vine. Very romantic, very me!

### Iris Purple — #5A4FCF

I want the purple of the flower named after a Greek goddess associated with rainbows. Mythology looks good on me!

### Mulberry — #70193D

Give me the dark reddish-purple of the fruit that grows on a mulberry tree. Not grapes, darling!

### Heather Purple — #B7A0C7

I want the purple of the tiny flowers that grow across open moorland. A whole hillside of them, just for my inspiration!

### Neon Orange — #FF5F1F

I want the glowing orange of the vest worn by road workers to stay visible. Safety first, fabulousness always!

### Rust Orange — #B7410E

Give me the reddish-orange that appears when iron sits in wet air for too long. Even oxidation has taste!

### Copper Orange — #B87333

I want the shiny orange-brown of the metal used in some old coins and electrical wires. Not gold, darling!

### Salmon Orange — #FA8072

Give me the orange-pink inside of a cooked salmon fillet. No carrots allowed in this kitchen!

### Mandarin Orange — #F37A16

I want the color of the peel of a small citrus fruit that is easy to divide into segments. Not a lemon, darling!

### Mahogany — #4C2B21

I want the reddish-brown of the wood used to make fine furniture and musical instruments. Only premium materials for me!

### Sepia — #704214

Give me the brown tone of an old photograph that looks like it came from another century. Vintage perfection!

### Tan — #D2B48C

I want the light brown of natural leather before it is dyed a darker color. Simple, classic, and flawless!

### Toffe Brown — #A16B4B

Give me the brown of chewy candy made by heating sugar and butter. Not a chocolate bar, darling!

### Espresso Brown — #3B2417

I want the nearly black-brown of a tiny, strong coffee served in a small cup. Intense, just like my personality!
