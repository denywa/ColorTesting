# Requirements Document

## Project Description (Input)

Playtesting Part II uses only RYB colors. Players need the same mix calculation for Manual Mix result feedback and the live Auto Mix bowl while keeping the existing match score.

## Introduction

This specification defines RYB-only color calculation, Manual Mix ingredient feedback, the current Auto Mix color, and match scoring. The match percentage is game feedback about perceptual similarity, not a measure of physical pigment accuracy.

## Boundary Context

- **In scope**: Blending RYB color units; ingredient proportions and Manual Mix result feedback; the current Auto Mix color; comparing an applied mix to its target; and the match score.
- **Out of scope**: Player input mapping, assigning colors, request creation and persistence, reassignment timing, action forwarding, phase orchestration, new scoring models, and local-network coordination.
- **Adjacent expectations**: Round flow supplies RYB units, mix mode, and target, then decides when to show a Manual result or the score. The UI specification owns the gameplay bowl and ratio-chart presentation.

## Requirements

### Requirement 1: RYB-only mixing
**Objective:** As a player, I want the shared mix to reflect how many units of each selected color were added, so that contributions change the displayed color consistently.

#### Acceptance Criteria
1. When a nonempty mix contains one distinct RYB color, the ColorGameTesting app shall use that color's stored display color as the result.
2. When a nonempty mix contains distinct RYB colors, the ColorGameTesting app shall use each accepted unit in the existing count-weighted RYB calculation, including primary-color proportions and black/white dilution, and display the corresponding color.
3. The ColorGameTesting app shall keep calculated result color channels within the displayable range.
4. The ColorGameTesting app shall not calculate a playtest round from a CMYK palette.

### Requirement 2: Ingredient proportions
**Objective:** As a player, I want to see the makeup of my mix, so that I can discuss the effect of each contribution.

#### Acceptance Criteria
1. When a mix contains units, the ColorGameTesting app shall calculate each distinct color's proportion as its unit count divided by the total unit count.
2. When a mix contains no units, the ColorGameTesting app shall provide no ingredient proportions.
3. While a Manual Mix result is displayed, the ColorGameTesting app shall list each distinct color in first-contribution order with its name, unit count, and proportion rounded to one decimal percent.

### Requirement 3: Result feedback
**Objective:** As a player, I want to inspect the finished color, so that I can discuss the mix before the round continues.

#### Acceptance Criteria
1. When a Manual Mix result exists, the ColorGameTesting app shall display a swatch of the calculated mix color and an ingredient breakdown.
2. If Manual Mix result data is unavailable, the ColorGameTesting app shall display a no-result message instead of a color swatch or breakdown.

### Requirement 4: Match scoring and comparison
**Objective:** As a player, I want a comparable score and visual target reference, so that I can judge how close the finished mix was to the request.

#### Acceptance Criteria
1. When a Manual Finish or Auto Apply action scores a nonempty mix, the ColorGameTesting app shall compare its displayed color with the round's target color using perceptual color difference and produce a match percentage from 0 to 100.
2. When the finished mix and target color are identical, the ColorGameTesting app shall assign a 100 percent match.
3. When the perceptual color difference is at least 100, the ColorGameTesting app shall assign a 0 percent match.
4. When a score exists, the ColorGameTesting app shall display the match percentage rounded to two decimal places and explain that higher percentages mean a closer match.
5. When a score and scored mix color exist, the ColorGameTesting app shall show the mix color beside the target color.
6. If score data is unavailable, the ColorGameTesting app shall display a no-score message instead of a match percentage.

### Requirement 5: Live Auto Mix color
**Objective:** As a player using Auto Mix, I want each contribution reflected in the current bowl color so that I can decide when to apply the mix.

#### Acceptance Criteria
1. When an accepted color unit changes an Auto Mix round, the ColorGameTesting app shall make the blended color of all currently accepted units available for immediate display.
2. While an Auto Mix round contains no color units, the ColorGameTesting app shall identify its current color as empty rather than display a calculated result color.
3. When Auto Apply scores the mix, the ColorGameTesting app shall use the color calculated from all accepted units at the time Apply takes effect.
