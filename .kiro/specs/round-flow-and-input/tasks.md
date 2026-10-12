# Implementation Plan: Round Flow and Input

These checked tasks record the existing single-device baseline. Source and test files cited below exist in the current working tree; this spec generation did not establish a passing full Xcode test run. No implementation gap was verified, so there are no open tasks.

- [x] 1. Establish settings and round creation
- [x] 1.1 Present single-device settings choices
  - Existing `ColorGameTesting/Views/SettingsView.swift` offers exclusive CMYK/RYB model choices, Random plus available requests, 15/30/45/60/90-second reassignment choices, a target-hint switch, and a Start Round action disabled without a selected model.
  - Existing `ColorGameTesting/GameViewModel.swift` defaults the duration to 45 seconds and the hint to off; `ColorGameTestingTests/GameViewModelTests.swift` checks model selection and confirmation gating.
  - The observable deliverable is a settings screen that permits Start Round only after a model choice and exposes the documented controls.
  - _Boundary: SettingsView and GameViewModel settings state_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 1.2 Integrate target choice with initial round state
  - Existing `GameViewModel.confirmSettings()` resolves an explicit available request ID or samples the combined request list for Random; `custom-color-requests` owns catalog construction and retention.
  - It creates one empty unlocked `Round`, assigns two slots to each of three players using all five palette colors plus one duplicate, resets result and score, starts the countdown, and enters playing.
  - Existing `GameViewModelTests` checks selected and available targets, both palette models, initial mix state, assignment coverage, and countdown reset.
  - The observable deliverable is a playing round with a selected target, six assigned slots, and an empty common mix.
  - _Boundary: GameViewModel and GameState round-creation integration_
  - _Requirements: 1.6, 2.1, 2.2, 4.1_

- [x] 2. Support active play
- [x] 2.1 Display the current shared round
  - Existing `ColorGameTesting/Views/GameView.swift` displays request text, assignments for all three players, the shared-mix chart, and remaining seconds; its hint swatch is conditional on the current setting.
  - Existing `ColorGameTestingTests/GameViewRenderingTests.swift` checks changes to the request, assignments, countdown, and mix visualization; the hint branch is visible in source.
  - The observable deliverable is a playing screen whose objective, assignments, mix, countdown, and optional hint track the current round.
  - _Boundary: GameView and ColorBarView presentation_
  - _Depends: 1.2_
  - _Requirements: 2.3, 2.4, 2.5_

- [x] 2.2 Integrate six local player controls
  - Existing `KeyRouter` maps Q/W, B/N, and O/P to the three players' primary/secondary slots; the macOS monitor is installed on entering playing. Existing iOS `GameView` renders two touch buttons for each player.
  - Both paths call `GameViewModel.addColor`, which appends one unit of the slot's current assigned color only during an unlocked playing round. Unknown keys, missing assignments, and actions in other phases do not append units.
  - Existing `KeyRouterTests`, `GameModelsTests`, `GameViewModelTests`, and `GameViewModelFlowTests` check the mapping, appended color, and rejected actions; iOS button wiring is source-inspected.
  - The observable deliverable is one common mix that gains exactly one current-color unit per valid local player action.
  - _Boundary: KeyRouter, GameView, and GameViewModel input integration_
  - _Depends: 1.2_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 2.3 Time and reassign player colors
  - Existing `GameViewModel.timerTick()` decreases the countdown while playing and unlocked. At zero, `triggerReassignment()` replaces six slots, increments `assignmentEpoch`, and resets the count to the configured duration without removing mix units.
  - Subsequent player actions read the current assignments. Mix locking or a phase change prevents another tick or reassignment; `GameViewModelTests` and `GameViewModelFlowTests` check countdown, retained units, new slot input, and stopped timing.
  - The observable deliverable is a recurring assignment change at the configured duration while the accumulated mix remains intact.
  - _Boundary: GameViewModel timer and assignments_
  - _Depends: 1.2_
  - _Requirements: 2.2, 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 3. Complete or redo the round
- [x] 3.1 Accept Mix only for a nonempty playing mix
  - Existing `GameView` disables Mix for an empty mix; `GameViewModel.pressMixButton()` also guards phase, lock, and nonempty input. An accepted action locks contributions, pauses the timer, removes the macOS key monitor, stores the upstream blend, and enters result.
  - Existing `GameViewModelFlowTests` checks rejected empty/locked actions, preserved units, computed result, stopped countdown, and result phase.
  - The observable deliverable is a calculated result for an accepted mix and no phase change for an empty or invalid mix.
  - _Boundary: GameView, GameViewModel, and color-calculation action seam_
  - _Depends: 2.2, 2.3_
  - _Requirements: 3.5, 4.5, 5.1, 5.2_

- [x] 3.2 Return a result to playing with Redo
  - Existing `ResultView` forwards Redo directly in single-device play. `GameViewModel.selectRedo()` clears units and result, unlocks the mix, preserves the request, assignments, and remaining count, then resumes the timer and reinstalls the macOS key monitor.
  - Existing `GameViewModelFlowTests.testRedoClearsMixAndResultButPreservesRequestAndCountdownThenResumes` checks the restored playing state and next accepted input.
  - The observable deliverable is an empty unlocked mix with the same round objective and remaining countdown, ready for another attempt.
  - _Boundary: ResultView and GameViewModel Redo action seam_
  - _Depends: 3.1_
  - _Requirements: 5.3_

- [x] 3.3 Finish a result and display the score
  - Existing `ResultView` forwards Finish directly in single-device play. `GameViewModel.selectFinish()` uses the upstream result-to-target scoring helpers, stores the percentage, and enters score while keeping the mix locked.
  - Existing `GameViewModelFlowTests.testFinishComputesMatchPercentageAndNewRoundResetsAllState` checks the score value and locked result; score presentation belongs to `color-mixing-and-scoring`.
  - The observable deliverable is a score phase with the calculated match percentage and frozen mix.
  - _Boundary: ResultView, GameViewModel, and scoring action seam_
  - _Depends: 3.1_
  - _Requirements: 5.4_

- [x] 3.4 Reset transient state for New Round
  - Existing `ScoreView` forwards New Round directly in single-device play. `GameViewModel.startNewRound()` removes any key monitor, clears round, selected model/request choice, result, score, round ID, and assignment epoch, then returns to settings.
  - Duration, hint, and saved custom requests remain available. Existing `GameViewModelFlowTests` checks the reset and invalid-phase actions; retained settings and catalog are visible in the view-model state layout.
  - The observable deliverable is a fresh settings phase without the prior round's transient values, ready for a new model and target choice.
  - _Boundary: ScoreView and GameViewModel New Round action seam_
  - _Depends: 3.3_
  - _Requirements: 5.5, 5.6, 5.7_

- [x] 4. Cover the baseline contracts with existing tests
- [x] 4.1 Check model, assignment, input, and timer rules
  - Existing `GameModelsTests`, `KeyRouterTests`, `GameStateTests`, and `GameViewModelTests` contain assertions for the four phases, three players, two slots, physical keys, initial round, random assignment composition, shared input, timer ticks, and reassignment preservation.
  - The observable deliverable is focused XCTest coverage of the domain and active-play contracts in those test files; a passing full suite was not verified in this spec run.
  - _Boundary: GameModelsTests, KeyRouterTests, GameStateTests, GameViewModelTests_
  - _Depends: 1.2, 2.2, 2.3_
  - _Requirements: 1.1, 1.5, 1.6, 2.1, 2.2, 3.1, 3.2, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 4.2 Check phase lifecycle and visible single-device route
  - Existing `GameViewModelFlowTests`, `GameViewRenderingTests`, and `ContentViewTests` contain assertions for rejected actions, Mix/Redo/Finish/New Round transitions, visible request/assignments/timer/mix, and the single-device settings route without network activity.
  - The observable deliverable is focused XCTest coverage of the end-to-end state path and displayed playing state in those test files; iOS touch wiring is source-inspected because its scheme has no test action.
  - _Boundary: GameViewModelFlowTests, GameViewRenderingTests, ContentViewTests_
  - _Depends: 2.1, 3.1, 3.2, 3.3, 3.4_
  - _Requirements: 2.3, 2.4, 2.5, 3.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_


The checked tasks above record the existing round-flow baseline. Playtesting Part II tasks below extend that shared controller. Complete `color-mixing-and-scoring` tasks 5.1–5.2 first so all callers use the approved RYB-only contract. Task 6 in that spec verifies the live/empty/apply handoff after round task 6.2 and before network protocol work.

- [x] 5. Add RYB and mix-mode settings to round state
- [x] 5.1 Retain a fixed RYB selection and capture the chosen mix mode
  - Remove palette selection and its Start gating; present RYB as the only palette and Manual Mix/Auto Mix as exclusive choices.
  - Default new settings and New Round to Manual; preserve target selection, duration choices/default, hint default, and saved request availability.
  - Capture the selected mode in each round. Keep the active round mode unchanged until that round ends.
  - Done when settings can start with RYB alone, create a round in either mode, and reset to Manual on New Round without losing retained settings/catalog data.
  - _Boundary: GameModels, GameState, GameViewModel settings state, SettingsView_
  - _Depends: color-mixing-and-scoring 5.1, 5.2_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 5.5, 5.6, 6.6_
- [x] 5.2 Guarantee a duplicate color never lands within one player's pair
  - Allocate the five palette colors and one duplicate across all six slots at round start and every reassignment.
  - Correct any generated same-player pair with a bounded swap that preserves palette coverage and exactly one cross-player duplicate.
  - Replace the test that expects a within-player duplicate; cover the correction case and reassignment.
  - Done when each of three players always receives different colors, all five colors appear, and exactly one color occurs twice.
  - _Boundary: GameViewModel assignments, GameViewModelTests_
  - _Depends: 5.1_
  - _Requirements: 2.1, 2.2, 2.6, 2.7, 4.3_

- [ ] 6. Support mode-specific round actions and live Auto color
- [x] 6.1 Update live color for every accepted Auto contribution
  - Maintain an optional live color separately from the frozen result; empty, Manual and scored states have no live color.
  - Recalculate from all accepted units after both solo input and host-accepted network input using the shared RYB mixer; client snapshot application accepts the host color without calculating it.
  - Keep current assignments, countdown, keyboard/touch mapping and contribution acceptance rules intact.
  - Done when one accepted unit updates the Auto color and the value matches blending the entire current bowl on either accepted input path.
  - _Boundary: GameState live color, GameViewModel input and applyRemoteState_
  - _Depends: 5.1, 5.2_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 6.1_
- [ ] 6.2 Apply or clear Auto Mix without a Manual result phase
  - Add shared eligibility for Mix, Apply, Redo, Finish and New Round; gate each action by phase, mode, lock and nonempty/result state.
  - Auto Apply freezes and scores the latest bowl directly into the score phase, stops timer/input, and retains the target; Auto Redo clears units/live color and continues playing with assignments and remaining time.
  - Preserve Manual Mix → result → Redo/Finish → score behavior and invalid-action no-ops; clear transient colors and reset mode on New Round.
  - Done when Auto never enters result, Apply uses the latest accepted contribution, both Redo paths preserve their required round data, and Manual flow remains unchanged.
  - _Boundary: GameViewModel action eligibility and transitions_
  - _Depends: 6.1_
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8_

- [ ] 7. Connect both round modes to functional screens
- [ ] 7.1 Show mode-specific controls and current bowl color
  - Settings displays the fixed RYB palette and both mix-mode choices. Gameplay keeps existing request, hint, assignment, countdown and platform inputs.
  - Manual shows its contribution chart and Mix action. Auto shows live color/empty state and Apply/Redo on the gameplay screen without the Manual ratio chart or Mix action.
  - Keep solo iOS six-slot touch controls and macOS key mappings; do not apply the separate modern layout redesign in this task.
  - Done when rendering assertions show the correct controls, mode and live/empty state and no CMYK options or previews remain.
  - _Boundary: SettingsView, GameView, existing ContentView phase routing_
  - _Depends: 6.1, 6.2_
  - _Requirements: 1.1, 1.2, 1.5, 2.3, 2.4, 2.5, 3.3, 6.1, 6.2, 6.8_
- [ ] 7.2 Cover round lifecycle, mode and regression contracts
  - Extend domain/flow tests for defaults, selected/random targets, color-pair invariants, input guards, timer/reassignment, Manual lifecycle, Auto Apply/Redo and New Round retention/reset.
  - Exercise empty actions, wrong modes/phases, currentBlend clearing/freezing, and the latest blend at Apply; keep custom-request and single-device routing regressions.
  - Done when focused macOS XCTest cases cover each transition and an iOS build/simulator smoke confirms the existing six solo controls still work.
  - _Boundary: GameModelsTests, GameStateTests, GameViewModelTests, GameViewModelFlowTests, GameViewRenderingTests, ContentViewTests_
  - _Depends: 5.1, 5.2, 6.1, 6.2, 7.1_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8_
