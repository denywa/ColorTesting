# Requirements Document

## Project Description (Input)

Playtesting Part II keeps the three-player round and reassignment loop while using RYB only, preventing duplicate colors within one player's pair, and offering Manual Mix and Auto Mix in single-device play.

## Introduction

This specification defines the single-device round lifecycle for both mix modes. Three players contribute to one transient RYB mix using two distinct assigned color slots each. Three-device play consumes these round rules but owns its own voting and synchronization.

## Boundary Context

- **In scope**: RYB-only single-device setup, Manual/Auto mode selection, round creation, distinct colors in each player's pair, input, reassignment, and direct mode-specific actions.
- **Out of scope**: Custom-request entry and retention, blend and score formulas, mode selection and network coordination, per-player scores, and session history.
- **Adjacent expectations**: Setup receives built-in and saved custom targets; color calculation supplies Manual results, live Auto color, and the match score. Their validation, persistence, and calculations remain in adjacent specifications. Three-device play applies a vote before the same round actions.

## Requirements

### Requirement 1: Configure a single-device round

**Objective:** As a group starting a playtest, I want to choose a mix mode, target, and pace so that I know how the round will work.

#### Acceptance Criteria

1. While single-device settings are shown, the ColorGameTesting app shall present RYB as the only palette.
2. While single-device settings are shown, the ColorGameTesting app shall offer Random and each available built-in or saved custom target as request choices.
3. While single-device settings are shown, the ColorGameTesting app shall offer reassignment durations of 15, 30, 45, 60, and 90 seconds, with 45 seconds selected by default.
4. While single-device settings are shown, the ColorGameTesting app shall offer a target-color hint switch that is off by default.
5. While single-device settings are shown, the ColorGameTesting app shall offer Manual Mix and Auto Mix as mutually exclusive choices with Manual Mix selected by default.
6. When the group starts a round, the ColorGameTesting app shall use the explicitly selected available request or choose one from all available requests when Random is selected.
7. When a round starts, the ColorGameTesting app shall retain the selected mix mode for that round.

### Requirement 2: Start and display the shared round

**Objective:** As one of three players, I want a clear assignment and shared objective so that I know what to add to the common mix.

#### Acceptance Criteria

1. When a round starts, the ColorGameTesting app shall create one empty, unlocked shared RYB mix for the selected target and mix mode.
2. When a round starts or colors are reassigned, the ColorGameTesting app shall give each of three players two different colors drawn from the five-color RYB palette.
3. While a round is playing, the ColorGameTesting app shall show the target request text, each player's current two assigned colors, the shared mix, and the reassignment countdown.
4. While a round is playing with the target-color hint enabled, the ColorGameTesting app shall show the target color beside its request text.
5. While a round is playing with the target-color hint disabled, the ColorGameTesting app shall omit that target-color hint.
6. When a round starts or colors are reassigned, the ColorGameTesting app shall place every RYB palette color in one of the six player slots.
7. When a round starts or colors are reassigned, the ColorGameTesting app shall place the one duplicated RYB color in slots belonging to different players.

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

**Objective:** As a group using Manual Mix, I want to inspect, redo, score, and restart a round so that the existing review step remains available.

#### Acceptance Criteria

1. If a Manual Mix shared mix is empty, the ColorGameTesting app shall prevent Mix from advancing to a result.
2. When Mix is activated for a nonempty unlocked Manual Mix round, the ColorGameTesting app shall lock contributions, stop the countdown, and display the calculated result and ingredient proportions.
3. When Redo is activated from a locked Manual Mix result, the ColorGameTesting app shall clear the mix and calculated result, retain the same request, assignments, and remaining countdown, then resume playing and the countdown.
4. When Finish is activated from a Manual Mix result with a calculated color, the ColorGameTesting app shall display the match score and keep the mix locked.
5. When New Round is activated from the score, the ColorGameTesting app shall return to settings with the prior round, request choice, result, and score cleared.
6. When New Round returns to settings, the ColorGameTesting app shall retain the current reassignment duration, target-hint setting, and available saved requests for another choice.
7. If Mix, Redo, Finish, or New Round is activated outside its valid phase or mix mode, the ColorGameTesting app shall leave the phase and round state unchanged.

### Requirement 6: Apply or redo an Auto Mix round

**Objective:** As a group using Auto Mix, I want the current blended color to update as we play and to apply or clear it without a separate Mix step.

#### Acceptance Criteria

1. When a color unit is accepted during an Auto Mix round, the ColorGameTesting app shall update the current blended color while keeping the round in the playing phase.
2. While an Auto Mix round is playing, the ColorGameTesting app shall make Apply and Redo available on the gameplay screen.
3. If the Auto Mix contains no units, the ColorGameTesting app shall prevent Apply and Redo from changing the round.
4. When Apply is activated for a nonempty Auto Mix, the ColorGameTesting app shall stop contributions and the countdown, then display the match score and the current blended color beside the target.
5. When Redo is activated for a nonempty Auto Mix, the ColorGameTesting app shall clear its units and current blended color while retaining the target, assignments, remaining countdown, and playing phase.
6. When New Round is activated from an Auto Mix score, the ColorGameTesting app shall return to settings with Manual Mix selected by default for the next round while retaining duration, hint setting, and saved requests.
7. If Apply or Redo is activated outside an eligible Auto Mix playing round, the ColorGameTesting app shall leave the phase and round state unchanged.
8. While an Auto Mix round is playing, the ColorGameTesting app shall omit the Manual Mix action.
