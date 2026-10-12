# Brief: round-flow-and-input

## Problem

The project owner and future contributors need a clear baseline of the complete playtest session. Setup choices, three-player controls, reassignment, and phase changes span several files, and no spec currently defines their shared behavior.

## Current State

In single-device mode, the app moves from settings to play, result, score, and back to settings for a new round. A round uses one shared mix and three players with two assigned color slots each. macOS uses keyboard input and iOS uses touch controls. Settings choose the color model, target request, reassignment duration, and optional target hint. The view model handles timed color reassignment, mix locking, redo, finish, and reset. A separate `local-three-device-play` spec covers the newer networked mode.

## Desired Outcome

A source-grounded spec describes the current session flow and input contract across both platforms, including how it consumes request and color-result capabilities, without turning current implementation details into new feature requests.

## Approach

Document the implemented phase state machine and player actions using `ContentView`, `GameViewModel`, `GameState`, `GameModels`, `KeyRouter`, relevant views, and tests. Keep algorithm and persistence ownership in their adjacent specs.

## Scope

- **In**: Setup options, request selection, round creation, player assignment and input, shared mix updates, timer and reassignment behavior, phase transitions, redo, finish, and new-round reset.
- **Out**: Request validation/storage internals, blend and score formulas, three-device local-network behavior, separate player scores, analytics, or new gameplay rules.

## Boundary Candidates

- `GameViewModel` and state models own round mutations, timing, and transitions.
- Views and `KeyRouter` translate platform-specific player actions into view-model calls.

## Out of Boundary

This spec consumes target requests and computed color results but does not own their persistence or calculation rules.

## Upstream / Downstream

- **Upstream**: `custom-color-requests` supplies optional custom targets; `color-mixing-and-scoring` supplies blend and scoring behavior.
- **Downstream**: Future playtest-driven changes can refine session setup, controls, pacing, and flow against this baseline.

## Existing Spec Touchpoints

- **Extends**: None; no specs exist yet.
- **Adjacent**: Custom request lifecycle and color result calculations remain in their respective specs. `local-three-device-play` owns mode selection, lobby, host/client coordination, network input, and synchronized phase display.

## Constraints

Describe existing macOS and iOS behavior and actual tests. A session is local, with three fixed players and transient round state. Do not infer unimplemented telemetry, history, or networking.
