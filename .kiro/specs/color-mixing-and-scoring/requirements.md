# Requirements Document

## Project Description (Input)

The project owner and future contributors need a stable description of the color feedback playtesters see. The current app already blends contributed colors and scores the finished mix, but no feature spec records the rules and result presentation. This baseline documents the implemented CMYK and RYB mixing, ingredient proportions, result feedback, and target comparison for future playtesting changes.

## Introduction

This specification records the current color calculation and feedback behavior for a completed single-device mix. The match percentage is game feedback about perceptual similarity, not a measure of physical pigment accuracy.

## Boundary Context

- **In scope**: Blending a round's accumulated units in its selected color model; ingredient proportions; the result swatch and breakdown; comparing the finished mix to the chosen target; and the score display.
- **Out of scope**: Player input mapping, assigning colors, request creation and persistence, reassignment timing, result-action forwarding, phase orchestration, new scoring models, and local-network coordination.
- **Adjacent expectations**: Round flow supplies a nonempty mix, selected model, and target, then decides when to show result and score. This specification defines the calculated values and their presentation once those inputs exist.

## Requirements

### Requirement 1: Palette-specific mixing
**Objective:** As a player, I want the shared mix to reflect how many units of each selected color were added, so that contributions change the displayed color consistently.

#### Acceptance Criteria
1. When a nonempty mix contains one distinct color, the ColorGameTesting app shall use that color's stored display color as the result.
2. When a nonempty mix contains distinct colors in a CMYK round, the ColorGameTesting app shall average their CMYK components with each unit contributing equally and display the corresponding color.
3. When a nonempty mix contains distinct colors in an RYB round, the ColorGameTesting app shall average their RYB components with each unit contributing equally and display the corresponding color.
4. The ColorGameTesting app shall keep calculated result color channels within the displayable range.

### Requirement 2: Ingredient proportions
**Objective:** As a player, I want to see the makeup of my mix, so that I can discuss the effect of each contribution.

#### Acceptance Criteria
1. When a mix contains units, the ColorGameTesting app shall calculate each distinct color's proportion as its unit count divided by the total unit count.
2. When a mix contains no units, the ColorGameTesting app shall provide no ingredient proportions.
3. When the result is displayed, the ColorGameTesting app shall list each distinct color in first-contribution order with its name, unit count, and proportion rounded to one decimal percent.

### Requirement 3: Result feedback
**Objective:** As a player, I want to inspect the finished color, so that I can discuss the mix before the round continues.

#### Acceptance Criteria
1. When a result exists, the ColorGameTesting app shall display a swatch of the calculated mix color and an ingredient breakdown.
2. If result data is unavailable, the ColorGameTesting app shall display a no-result message instead of a color swatch or breakdown.

### Requirement 4: Match scoring and comparison
**Objective:** As a player, I want a comparable score and visual target reference, so that I can judge how close the finished mix was to the request.

#### Acceptance Criteria
1. When the finished mix is scored, the ColorGameTesting app shall compare its displayed color with the round's target color using perceptual color difference and produce a match percentage from 0 to 100.
2. When the finished mix and target color are identical, the ColorGameTesting app shall assign a 100 percent match.
3. When the perceptual color difference is at least 100, the ColorGameTesting app shall assign a 0 percent match.
4. When a score exists, the ColorGameTesting app shall display the match percentage rounded to two decimal places and explain that higher percentages mean a closer match.
5. When a score, round, and mix result exist, the ColorGameTesting app shall show the mix color beside the target color.
6. If score data is unavailable, the ColorGameTesting app shall display a no-score message instead of a match percentage.
