# Brief: modern-playtest-ui

## Problem

Playtesters need to understand their colors, the shared bowl, the target request, mix mode, and group decisions at a glance. The current interface is vertically stacked on iOS, and the three-device gameplay screen does not match the landscape arrangement requested after playtesting.

## Current State

The SwiftUI app has setup, lobby, gameplay, result, and score screens on macOS and iOS; the current iOS target also includes iPad. The iPhone gameplay view shows only the local player's two colors in three-device play, but its layout is vertical. The current result flow is Manual Mix only. The existing specs own the game rules and local-play coordination; they will be updated separately for Playtesting Part II.

## Desired Outcome

All iPhone and macOS screens have a coherent, clearer, modern visual design, with gameplay addressed first. On iPhone, the app presents in landscape. In three-device gameplay, the request is at the upper left, the bowl is central, and the local player's two color controls sit at the lower left and right. Manual Mix places Mix beneath the bowl, then shows the ingredient ratios with Apply/Finish and Redo actions. Auto Mix shows the blended bowl immediately, without a ratio pie chart, and offers Apply and Redo on the same screen. Apply/Finish shows the difference from the target color. Three-device actions show each player's vote and pending agreement clearly.

## Approach

Evolve the existing SwiftUI views and shared state in stages, using the saved [layout sketch](assets/playtesting-part-ii-layout.png) as a placement reference rather than a finished visual style. Reuse current view-model actions and local coordinator state; add focused presentation components only where the existing structure needs them. Keep iPhone landscape orientation and the removal of iPad from the iOS target in this spec's implementation scope.

## Scope

- **In**: Visual hierarchy, spacing, typography, controls, responsive landscape iPhone layouts, action and vote status presentation, accessibility, and visual consistency across setup, lobby, gameplay, result, and score on iPhone and macOS.
- **Out**: iPad support, color blending and scoring formulas, assignment rules, mix-mode phase rules, vote counting or authority, and network protocol behavior.

## Boundary Candidates

- Shared visual language across screens and platforms.
- Gameplay presentation for one-device and three-device sessions, including Manual Mix, Auto Mix, and vote progress.
- iPhone landscape orientation and layout adaptation across supported iPhone sizes.

## Out of Boundary

This spec does not decide when Mix, Apply/Finish, or Redo becomes valid, how votes are counted, or which color a player receives. It displays those decisions from the round-flow and local-play state.

## Upstream / Downstream

- **Upstream**: `GameViewModel`, RYB color data and mixing, `LocalPlayCoordinator`, shared snapshots, and the updated color-mixing-and-scoring, round-flow-and-input, and local-three-device-play specs.
- **Downstream**: iOS and macOS playtesting, usability feedback, and later visual refinements.

## Existing Spec Touchpoints

- **Extends**: No existing spec's presentation ownership; this is a new UI boundary.
- **Adjacent**: `color-mixing-and-scoring` owns calculated color and Manual Mix proportions; `round-flow-and-input` owns mode and phase behavior; `local-three-device-play` owns majority votes and synchronization; `custom-color-requests` owns request entry and persistence.

## Constraints

Use native SwiftUI and the current app architecture without a new dependency. Preserve direct actions in one-device play. In three-device play, show a separate vote from each player's device and execute the action as soon as two players vote for it. The iOS target currently includes iPad; remove that target family. The iPhone layout must work in landscape on supported iPhones, while macOS retains usable keyboard controls. Verify orientation and touch ergonomics on devices when Xcode is available; the current environment cannot run `xcodebuild` because its active developer directory is Command Line Tools. Write the future specification in English, matching `spec.json.language` when initialized.
