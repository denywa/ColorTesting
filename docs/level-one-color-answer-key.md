# Level 1 Color Requests — Targets and Answer Key

These are selected gameplay target colors, not a claim that every color name has one universal hex definition. All 40 supplied prompts are added to Level 1. The seven original placeholder requests have been removed from the built-in catalog.

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
| Sky Blue | `#87CEEB` | 0 | 4 | 10 | 0 | 15 | 29 | `#9EBBC9` | 94.03% |
| Baby Blue | `#89CFF0` | 0 | 2 | 5 | 0 | 8 | 15 | `#A2BDCB` | 93.73% |
| Powder Blue | `#B0E0E6` | 0 | 1 | 2 | 0 | 5 | 8 | `#B7D1CE` | 96.20% |
| Ice Blue | `#D6F1FF` | 0 | 2 | 5 | 0 | 23 | 30 | `#D0DEE5` | 96.90% |
| Cyan | `#5BC8D6` | 0 | 5 | 11 | 0 | 11 | 27 | `#8BB2B7` | 91.54% |

### Red

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Cherry Red | `#D2042D` | 15 | 0 | 2 | 2 | 0 | 19 | `#D2092E` | 99.85% |
| Scarlet | `#FF2400` | 7 | 1 | 0 | 0 | 0 | 8 | `#FC2C0F` | 99.48% |
| Crimson | `#DC143C` | 24 | 1 | 4 | 0 | 1 | 30 | `#DC183C` | 99.82% |
| Burgundy | `#800020` | 13 | 0 | 2 | 12 | 0 | 27 | `#810621` | 99.66% |
| Ruby Red | `#E0115F` | 20 | 0 | 5 | 0 | 1 | 26 | `#DF1A5E` | 99.76% |

### Yellow

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Lemon Yellow | `#FFF44F` | 2 | 17 | 0 | 0 | 7 | 26 | `#FDF34E` | 99.85% |
| Sunshine Yellow | `#FFD700` | 7 | 19 | 0 | 0 | 0 | 26 | `#F9D521` | 99.25% |
| Mustard Yellow | `#FFDB58` | 7 | 15 | 0 | 0 | 6 | 28 | `#F9D855` | 99.45% |
| Golden Yellow | `#FFCC33` | 8 | 14 | 0 | 0 | 1 | 23 | `#F7C936` | 99.22% |
| Butter Yellow | `#FFF1A8` | 1 | 3 | 0 | 0 | 6 | 10 | `#FDEFA5` | 99.75% |

### Green

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Mint Green | `#98FF98` | 0 | 9 | 8 | 0 | 12 | 29 | `#A7E18B` | 95.21% |
| Lime Green | `#BFFF00` | 0 | 21 | 5 | 0 | 1 | 27 | `#C4EB20` | 97.39% |
| Forest Green | `#228B22` | 0 | 10 | 10 | 9 | 0 | 29 | `#428A29` | 98.52% |
| Olive Green | `#808000` | 0 | 1 | 0 | 1 | 0 | 2 | `#808000` | 99.90% |
| Sage Green | `#9CAF88` | 0 | 3 | 2 | 6 | 11 | 22 | `#9DAF8A` | 99.71% |

### Pink

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Bubblegum Pink | `#FF85C2` | 11 | 0 | 4 | 0 | 14 | 29 | `#E886B8` | 98.03% |
| Blush Pink | `#F4C2C2` | 5 | 0 | 0 | 1 | 19 | 25 | `#F5C2C2` | 99.88% |
| Hot Pink | `#FF69B4` | 9 | 0 | 3 | 0 | 8 | 20 | `#E672A8` | 97.76% |
| Dusty Pink | `#D8A0A6` | 4 | 1 | 1 | 0 | 8 | 14 | `#D8A2A2` | 98.85% |
| Pastel Pink | `#FFD1DC` | 5 | 0 | 1 | 0 | 24 | 30 | `#F9CFDB` | 99.43% |

### Purple

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Lavender | `#C8B4F4` | 2 | 0 | 6 | 1 | 19 | 28 | `#C5B3F1` | 99.70% |
| Violet | `#8F00FF` | 10 | 0 | 16 | 0 | 1 | 27 | `#8828E5` | 98.43% |
| Grape Purple | `#6F2DA8` | 6 | 0 | 9 | 6 | 2 | 23 | `#6F2CAA` | 99.79% |
| Plum Purple | `#673147` | 7 | 1 | 3 | 14 | 4 | 29 | `#663049` | 99.43% |
| Lilac | `#C8A2C8` | 5 | 1 | 4 | 2 | 16 | 28 | `#C7A2C9` | 99.84% |

### Orange

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Carrot Orange | `#ED9121` | 13 | 10 | 0 | 1 | 0 | 24 | `#EA9333` | 99.22% |
| Peach | `#FFCBA4` | 5 | 3 | 0 | 0 | 10 | 18 | `#FBC9A2` | 99.63% |
| Tangerine | `#F28500` | 16 | 11 | 0 | 1 | 0 | 28 | `#EC8B30` | 98.51% |
| Burnt Orange | `#CC5500` | 15 | 7 | 0 | 5 | 0 | 27 | `#CA5C20` | 98.65% |
| Apricot | `#FBCEB1` | 6 | 3 | 0 | 0 | 16 | 25 | `#FCCEB2` | 99.64% |

### Brown

| Color | Target hex | Red | Yellow | Blue | Black | White | Total | Mixed hex | Match |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| Dark Chocolate | `#3B1F16` | 5 | 3 | 2 | 14 | 0 | 24 | `#3C2118` | 99.54% |
| Caramel Brown | `#AF6F3C` | 11 | 8 | 3 | 0 | 0 | 22 | `#B06F3A` | 99.80% |
| Chestnut Brown | `#954535` | 10 | 2 | 0 | 12 | 5 | 29 | `#944434` | 99.85% |
| Beige | `#D9C3A5` | 5 | 4 | 0 | 4 | 17 | 30 | `#DAC0A1` | 99.16% |
| Taupe | `#8B7E74` | 3 | 2 | 1 | 11 | 12 | 29 | `#8B7D75` | 99.42% |

## Target selection notes

Cyan uses pool-water cyan **#5BC8D6**, matching the swimming-pool prompt. Pure display cyan #00FFFF achieved only approximately 65.13% in the same bounded search with the current RYB mixer, so it was not selected as a Level 1 target.

The Ruby Red prompt is stored exactly as supplied and ends with “a royal treasure” without added punctuation or invented copy.

## Exact request text

### Sky Blue — #87CEEB

I want the color of a clear blue summer sky. Make me look heavenly, darling!

### Baby Blue — #89CFF0

Give me the soft blue of a baby's blanket. Cute, precious, and obviously expensive.

### Powder Blue — #B0E0E6

I want the pale blue of a delicate porcelain teacup. Yes, my hair deserves fine dining.

### Ice Blue — #D6F1FF

Give me the color of blue ice in a freezer. Cold, flawless, and emotionally unavailable.

### Cyan — #5BC8D6

I want the bright blue of a swimming pool or clear sea water on a sunny day. Make a splash, please!

### Cherry Red — #D2042D

I want the color of ripe red cherries. Sweet, shiny, and dangerously gorgeous. Just like me!

### Scarlet — #FF2400

Give me the bright red of a superhero's cape. The world needs to notice my entrance.

### Crimson — #DC143C

I want the deep red of a velvet theater curtain. Drama is my birthright, darling.

### Burgundy — #800020

Give me the dark red of a fancy evening dress. I don't do cheap-looking entrances.

### Ruby Red — #E0115F

I want the red of a ruby gemstone. Make me look like I belong in a royal treasure

### Lemon Yellow — #FFF44F

I want the bright yellow of a lemon. Sour attitude, fabulous hair!

### Sunshine Yellow — #FFD700

Give me the bright yellow of sunshine pouring through a window. The world revolves around me!

### Mustard Yellow — #FFDB58

I want the yellow of mustard sauce. Bold, spicy, and impossible to ignore.

### Golden Yellow — #FFCC33

Give me the color of shiny gold jewelry. I expect nothing less than royal treatment.

### Butter Yellow — #FFF1A8

I want the soft yellow of a stick of butter. Smooth, rich, and ready for the spotlight.

### Mint Green — #98FF98

I want the fresh green of mint leaves in a cold drink. Refreshing, just like my presence!

### Lime Green — #BFFF00

Give me the bright green of a lime peel. Sour face, sweet style!

### Forest Green — #228B22

I want the deep green of a thick forest. I own the trees now, darling.

### Olive Green — #808000

Give me the muted green of green olives. Mediterranean luxury, obviously.

### Sage Green — #9CAF88

I want the soft, dusty green of sage leaves. Calm, elegant, and far above the drama.

### Bubblegum Pink — #FF85C2

I want the bright pink of bubblegum. Sweet, loud, and impossible to ignore. Like me!

### Blush Pink — #F4C2C2

Give me the soft pink of cheeks after a tiny compliment. I'm naturally adorable, darling.

### Hot Pink — #FF69B4

I want a loud, intense pink. If people can ignore me, you have failed.

### Dusty Pink — #D8A0A6

Give me the muted pink of an old rose. Vintage, elegant, and still better than everyone.

### Pastel Pink — #FFD1DC

I want a pale, gentle pink, like a pastel birthday decoration. Cute is my natural state.

### Lavender — #C8B4F4

I want the pale purple of lavender flowers. Relaxing, elegant, and expensive-smelling.

### Violet — #8F00FF

Give me the vivid purple of a violet flower. Small flower, enormous personality. Just like me!

### Grape Purple — #6F2DA8

I want the rich purple of purple grapes. Fruit royalty has arrived!

### Plum Purple — #673147

Give me the dark purple skin of a ripe plum. Sweet, mysterious, and very exclusive.

### Lilac — #C8A2C8

I want the light purple of lilac blossoms. Delicate, darling, but never forgettable.

### Carrot Orange — #ED9121

I want the bright orange of a carrot. Bugs Bunny could never wear it this well!

### Peach — #FFCBA4

Give me the soft orange-pink of a ripe peach. Sweet, fuzzy, and fabulous.

### Tangerine — #F28500

I want the bright orange of a tangerine peel. Citrus energy, premium attitude!

### Burnt Orange — #CC5500

Give me the deep orange of autumn leaves. Warm, dramatic, and impossible to replace.

### Apricot — #FBCEB1

I want the soft orange of an apricot fruit. Delicate, juicy, and naturally superior.

### Dark Chocolate — #3B1F16

I want the dark brown of a chocolate bar with very little milk. Bitter, rich, and expensive. Like my standards!

### Caramel Brown — #AF6F3C

Give me the warm brown of melted caramel. Sweet, smooth, and impossible to resist.

### Chestnut Brown — #954535

I want the rich brown of a chestnut shell. Autumn elegance, darling!

### Beige — #D9C3A5

Give me the pale brown of sand on a quiet beach. Neutral, classy, and never boring when I wear it.

### Taupe — #8B7E74

I want the grayish brown of a taupe sofa. Interior design has finally found its muse.
