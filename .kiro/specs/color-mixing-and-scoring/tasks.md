# Implementation Plan

These checked tasks record the existing baseline. They do not request new implementation. The cited tests exist, but this spec run did not verify a passing Xcode test execution.

- [x] 1. Establish the color calculation baseline
- [x] 1.1 Blend each palette in its native component space
  - Existing `ColorGameTesting/ColorMixer.swift` returns the stored display color for one distinct ID, averages each unit's CMYK or RYB components for mixed IDs, converts to display color, and clamps calculated channels.
  - Existing `ColorGameTestingTests/ColorMixerTests.swift` contains identity, weighted mean, CMYK, RYB, corner, and clamping assertions.
  - The deliverable is a display color for each valid nonempty mix in either selected palette.
  - _Boundary: ColorMixer_
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 1.2 Calculate ingredient proportions by distinct color
  - Existing `ColorGameTesting/GameState.swift` calculates each color ID's unit count divided by all units and returns no ratios for an empty mix.
  - Existing `ColorGameTestingTests/MixRatiosTests.swift` and `ColorGameTestingTests/GameViewModelFlowTests.swift` contain nonempty and cleared-mix assertions.
  - The deliverable is a ratio per distinct color for nonempty mixes and an empty ratio map for empty mixes.
  - _Boundary: Mix.ratios_
  - _Requirements: 2.1, 2.2_

- [x] 1.3 Convert displayed colors to perceptual color coordinates
  - Existing `ColorGameTesting/ColorConverter.swift` converts sRGB to Lab using its fixed transfer, matrix, and reference white.
  - Existing `ColorGameTestingTests/ColorConverterTests.swift` contains reference-color and round-trip assertions.
  - The deliverable is a Lab value for both the mix result and target before scoring.
  - _Boundary: ColorConverter_
  - _Requirements: 4.1_

- [x] 1.4 Calculate the calibrated match percentage
  - Existing `ColorGameTesting/ScoreCalculator.swift` calculates Delta E 2000 and maps a capped difference to the 0–100 game percentage.
  - Existing `ColorGameTestingTests/ScoreCalculatorTests.swift` contains reference pairs, endpoints, bounds, and perceptual-order assertions.
  - The deliverable is 100 for an identical Lab pair and 0 at a difference of 100 or greater.
  - _Boundary: ScoreCalculator_
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 2. Present calculated feedback
- [x] 2.1 Show the result swatch and ingredient breakdown
  - Existing `ColorGameTesting/Views/ResultView.swift` displays the current mix color, first-contribution-order rows, counts, one-decimal percentages, and a no-result fallback.
  - Existing `ColorGameTestingTests/ResultViewTests.swift` contains order, count, rounding, and rendering assertions.
  - The deliverable is a readable result screen when round and result data exist and `No Mix Result` otherwise.
  - _Boundary: ResultView_
  - _Requirements: 2.3, 3.1, 3.2_

- [x] 2.2 Show the match percentage and target comparison
  - Existing `ColorGameTesting/Views/ScoreView.swift` formats the score to two decimals, explains its direction, shows mix and target swatches when available, and displays a no-score fallback.
  - Existing `ColorGameTestingTests/ScoreViewTests.swift` contains a two-decimal rendering assertion.
  - The deliverable is a score display with optional color comparison when score data exist and `No Score` otherwise.
  - _Boundary: ScoreView_
  - _Requirements: 4.4, 4.5, 4.6_

- [x] 3. Connect calculations to the existing round lifecycle
  - Existing `ColorGameTesting/GameViewModel.swift` invokes mixing for an accepted nonempty playing mix and converts the result and target before scoring an accepted Finish action.
  - The deliverable is a stored mix result for the result screen and a stored percentage for the score screen at the existing phase seam.
  - _Boundary: GameViewModel integration seam_
  - _Depends: 1.1, 1.3, 1.4_
  - _Requirements: 3.1, 4.1, 4.4, 4.5_

- [x] 4. Cover the calculation handoff with flow checks
  - Existing `GameViewModelFlowTests` assert an accepted mix stores the expected result color and scoring stores the calculated percentage.
  - The deliverable is existing integration evidence for the result and score values supplied to their screens.
  - _Boundary: GameViewModel calculation seam_
  - _Requirements: 4.1_
