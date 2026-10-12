# Requirements Document

## Project Description (Input)

The project owner and future contributors need a clear baseline of the complete playtest session. The current single-device app already moves through settings, play, result, score, and back to settings, but no feature spec records how setup choices, three-player input, timed reassignment, and phase transitions work together. This baseline documents that existing behavior on macOS and iOS for future playtesting changes.

## Introduction

This specification records the implemented single-device round lifecycle. Three players contribute to one transient mix using two assigned color slots each. The same phase sequence is also consumed by the separate three-device mode, but its coordination rules are outside this specification.

## Boundary Context

- **In scope**: Single-device setup, round creation, assignments and player input, reassignment countdown, mix locking, Redo, Finish, and New Round transitions.
- **Out of scope**: Custom-request entry and retention, blend and score formulas, mode selection and network coordination, per-player scores, and session history.
- **Adjacent expectations**: Setup receives built-in and saved custom targets; an accepted Mix action receives a calculated color, and Finish receives a calculated match percentage. Their validation, persistence, and calculations remain in adjacent specifications.

## Requirements

### Requirement 1: Configure a single-device round

**Objective:** As a group starting a playtest, I want to choose the round conditions so that we can compare different palettes, targets, and pacing.

#### Acceptance Criteria

1. While single-device settings are shown, the ColorGameTesting app shall offer CMYK and RYB as mutually exclusive color-model choices.
2. While single-device settings are shown, the ColorGameTesting app shall offer Random and each available built-in or saved custom target as request choices.
3. While single-device settings are shown, the ColorGameTesting app shall offer reassignment durations of 15, 30, 45, 60, and 90 seconds, with 45 seconds selected by default.
4. While single-device settings are shown, the ColorGameTesting app shall offer a target-color hint switch that is off by default.
5. If no color model is selected, the ColorGameTesting app shall prevent the round from starting.
6. When the group starts a round with a color model selected, the ColorGameTesting app shall use the explicitly selected available request or choose one from all available requests when Random is selected.

### Requirement 2: Start and display the shared round

**Objective:** As one of three players, I want a clear assignment and shared objective so that I know what to add to the common mix.

#### Acceptance Criteria

1. When a round starts, the ColorGameTesting app shall create one empty, unlocked shared mix for the selected color model and target.
2. When a round starts or colors are reassigned, the ColorGameTesting app shall give each of three players two color slots drawn from the selected five-color palette, with every palette color present and one color duplicated across the six slots.
3. While a round is playing, the ColorGameTesting app shall show the target request text, each player's current two assigned colors, the shared mix, and the reassignment countdown.
4. While a round is playing with the target-color hint enabled, the ColorGameTesting app shall show the target color beside its request text.
5. While a round is playing with the target-color hint disabled, the ColorGameTesting app shall omit that target-color hint.

### Requirement 3: Accept three-player color input

**Objective:** As a player, I want my assigned control to add the color I currently see so that all three players can build one mix together.

#### Acceptance Criteria

1. When a player activates either assigned color slot during an unlocked playing round, the ColorGameTesting app shall append one unit of that slot's current color to the shared mix.
2. Where the round is played on macOS, the ColorGameTesting app shall map Q/W to Player 1, B/N to Player 2, and O/P to Player 3, with the first key of each pair selecting the primary slot.
3. Where the round is played on iOS, the ColorGameTesting app shall offer touch buttons for both assigned colors of all three players.
4. If an unassigned keyboard key is pressed, the ColorGameTesting app shall leave the mix unchanged.
5. If a color action occurs outside an unlocked playing round, the ColorGameTesting app shall leave the mix unchanged.

### Requirement 4: Reassign colors without losing contributions

**Objective:** As a group, I want assignments to change at the configured pace while keeping our accumulated mix so that the round continues smoothly.

#### Acceptance Criteria

1. When an unlocked playing round begins, the ColorGameTesting app shall start the reassignment countdown at the selected duration.
2. While an unlocked round is playing, the ColorGameTesting app shall decrease the remaining countdown once per elapsed second.
3. When the countdown reaches zero during an unlocked playing round, the ColorGameTesting app shall replace all three player assignments, retain the existing mix, and reset the countdown to the selected duration.
4. When colors are reassigned, the ColorGameTesting app shall apply subsequent slot actions to the newly displayed colors.
5. While a round is locked or displayed outside playing, the ColorGameTesting app shall not advance its countdown or reassign its colors.

### Requirement 5: Move through result, score, and another round

**Objective:** As a group, I want to inspect, redo, score, and restart a round so that a playtest session can continue without rebuilding the app state manually.

#### Acceptance Criteria

1. If the shared mix is empty, the ColorGameTesting app shall prevent the Mix action from advancing to a result.
2. When Mix is activated for a nonempty unlocked playing mix, the ColorGameTesting app shall lock contributions, stop the countdown, and display the calculated result.
3. When Redo is activated from a locked result, the ColorGameTesting app shall clear the mix and calculated result, retain the same request, assignments, and remaining countdown, then resume playing and the countdown.
4. When Finish is activated from a result with a calculated color, the ColorGameTesting app shall display the match score and keep the mix locked.
5. When New Round is activated from the score, the ColorGameTesting app shall return to settings with the prior round, model choice, request choice, result, and score cleared.
6. When New Round returns to settings, the ColorGameTesting app shall retain the current reassignment duration, target-hint setting, and available saved requests for another choice.
7. If Mix, Redo, Finish, or New Round is activated outside its valid phase, the ColorGameTesting app shall leave the phase and round state unchanged.
