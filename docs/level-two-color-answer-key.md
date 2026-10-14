# Level 2 Color Requests — Targets and Answer Key

These are selected gameplay target colors, not a claim that every color name has one universal hex definition. All 23 unique supplied prompts are added to Level 2. Pumpkin Orange was supplied twice with identical copy, so it appears once.

## Reading the recipes

- Counts are units (color taps), in the order Red, Yellow, Blue, Black, White. Zero means do not add that color.
- Recipes use the current `ColorMixer`, `ColorConverter`, and `ScoreCalculator` implementations for both Manual and Auto Mix.
- The search evaluated every non-empty integer combination with **at most 30 total units**: 324,631 candidates per target. The recipe minimizes Delta E 2000 within this limit; exact ties prefer fewer units.
- Scores use the unrounded mixed RGB values. The displayed mixed hex is rounded to 8-bit RGB for reference, so calculating from that hex alone can differ slightly.
- All listed recipes exceed the default 70% passing threshold. They are bounded-search results, not a proof of the closest possible mixture with unlimited units.
- Apply/Finish after adding the listed quantities. Player color assignments and reassignment timing determine who can contribute each ingredient.

## Target colors and closest recipes

### Blue

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Turquoise | `#40E0D0` | 0 | 4 | 7 | 0 | 8 | 19 | `#94C0AD` | 84.29% |
| Teal Blue | `#008080` | 0 | 9 | 19 | 0 | 0 | 28 | `#3E8182` | 97.78% |
| Ocean Blue | `#005B96` | 0 | 7 | 20 | 3 | 0 | 30 | `#2D5D8B` | 98.61% |
| Royal Blue | `#4169E1` | 0 | 3 | 17 | 0 | 6 | 26 | `#5169D2` | 98.77% |
| Blue ink pen | `#1A43BF` | 0 | 1 | 5 | 0 | 0 | 6 | `#2043BE` | 99.80% |

### Red

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Tomato Red | `#FF6347` | 17 | 3 | 0 | 0 | 6 | 26 | `#FC6449` | 99.72% |
| Brick Red | `#B55239` | 8 | 2 | 0 | 5 | 3 | 18 | `#B65238` | 99.87% |
| Rust Red | `#B7410E` | 14 | 5 | 0 | 7 | 0 | 26 | `#B64417` | 99.45% |
| Rose Red | `#C21E56` | 14 | 1 | 4 | 1 | 1 | 21 | `#C12256` | 99.76% |
| Chili Red | `#D62828` | 17 | 0 | 0 | 4 | 4 | 25 | `#D62929` | 99.92% |

### Yellow

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Honey Yellow | `#DDAF26` | 10 | 16 | 0 | 3 | 0 | 29 | `#DCAF2A` | 99.84% |
| Banana Yellow | `#FFE135` | 6 | 20 | 0 | 0 | 3 | 29 | `#FADF34` | 99.56% |
| Sponge Cake Yellow | `#F4D35E` | 7 | 14 | 0 | 1 | 7 | 29 | `#F0D15B` | 99.65% |
| Golden Yellow | `#FFC000` | 11 | 16 | 0 | 0 | 0 | 27 | `#F5BF32` | 98.64% |
| Vanilla Yellow | `#F3E5AB` | 3 | 7 | 0 | 1 | 18 | 29 | `#F4E6AB` | 99.83% |

### Green

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Moss Green | `#8A9A5B` | 0 | 6 | 2 | 9 | 8 | 25 | `#8A9A5B` | 99.91% |
| Jade Green | `#00A86B` | 0 | 2 | 3 | 0 | 0 | 5 | `#4DA063` | 97.29% |
| Hunter Green | `#355E3B` | 2 | 7 | 9 | 8 | 0 | 26 | `#365E3C` | 99.86% |
| Matcha Latte | `#A8B876` | 0 | 7 | 2 | 7 | 12 | 28 | `#A9B776` | 99.85% |
| Mint Ice Cream | `#B7E4C7` | 0 | 5 | 7 | 0 | 18 | 30 | `#B9DCBE` | 98.58% |

### Orange

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Pumpkin Orange | `#FF7518` | 19 | 10 | 0 | 0 | 0 | 29 | `#F77A2A` | 99.08% |

### Brown

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Cocoa Brown | `#6F4E37` | 9 | 7 | 4 | 7 | 1 | 28 | `#6F4F36` | 99.55% |
| Mocha | `#967969` | 4 | 2 | 0 | 11 | 10 | 27 | `#957967` | 99.68% |

## Exact request text

### Turquoise — #40E0D0

Give me the color of tropical water around a sunny island. Well, I deserve a private beach.

### Teal Blue — #008080

I want the color on a teal duck's head. Nature clearly designed it for someone as fabulous as me.

### Ocean Blue — #005B96

Give me the color of the sea far below the surface, where sunlight barely reaches. Mysterious, just like my beauty!

### Royal Blue — #4169E1

I want the bold blue associated with royal robes and grand ceremonies. Make me look ready to take the throne!

### Blue ink pen — #1A43BF

Honey, give me the color of the ink inside a classic blue ballpoint pen. You know, the one you borrow and NEVER return!

### Tomato Red — #FF6347

I want the color of the fruit people slice for burgers and salads. Round, juicy, and obviously iconic!

### Brick Red — #B55239

Give me the color of traditional clay bricks used to build house walls. Not painted bricks, darling. The classic ones straight from the construction site!

### Rust Red — #B7410E

I want the color that appears on iron left outside in the rain for too long. Even old metal has style!

### Rose Red — #C21E56

Darling, I want the classic rose from a romantic date. The one with velvety petals that people give when they say ‘I love you.’ A whole bouquet of them, please!

### Chili Red — #D62828

Give me the color of a fully ripe chili pepper. The spicy little diva that turns your favorite sambal into a fiery masterpiece!

### Honey Yellow — #DDAF26

Give me the color of the sweet liquid made by bees and stored in a jar. Nature's luxury product!

### Banana Yellow — #FFE135

I want the color of a ripe fruit monkeys love. Not green, not brown. The perfect snack!

### Sponge Cake Yellow — #F4D35E

Give me the color of the inside of a freshly baked sponge cake. That sunny, fluffy center that makes every tea party fabulous!

### Golden Yellow — #FFC000

Sweetheart, give me the golden color of a shiny gold coin. Rich, bright, and expensive-looking. Naturally, just like me!

### Vanilla Yellow — #F3E5AB

Give me the soft, creamy color of vanilla pudding. Smooth, sweet, and delicate enough for my royal taste!

### Moss Green — #8A9A5B

I want the color of the soft growth that covers damp stones and tree trunks. Woodland chic, darling!

### Jade Green — #00A86B

I want the color of the polished green stone used to make bracelets and carved ornaments. Ancient treasure, modern diva!

### Hunter Green — #355E3B

Give me the dark green associated with traditional outdoor jackets and forest clothing. Rugged, but still runway-ready!

### Matcha Latte — #A8B876

Make it like my matcha latte order. Extra fancy, perfectly whisked, and absolutely NOT the cheap stuff!

### Mint Ice Cream — #B7E4C7

One scoop of mint ice cream, please! Cool, creamy, and expensive-looking. Unlike my last situationship.

### Pumpkin Orange — #FF7518

Give me the color of the big round fruit people carve into spooky faces for Halloween. Scary? Only my beauty!

### Cocoa Brown — #6F4E37

I want the brown powder people use to make chocolate desserts. Sweetness is optional, darling!

### Mocha — #967969

Give me the color inspired by a drink made with coffee and chocolate together. Two classics, one flawless customer!

The Sponge Cake Yellow prompt had no closing quotation mark in the supplied list; its request text ends at the exclamation mark.
