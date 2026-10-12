# Brief: custom-color-requests

## Problem

The project owner and future contributors need an accurate baseline for how playtesters add and reuse target requests. The behavior exists in code, but there is no spec to distinguish request storage and validation from round selection.

## Current State

The settings UI accepts a request name and hex color. `GameViewModel` validates the input, adds a `ColorRequest`, selects it for the next round, and uses `CustomRequestStore` to retain custom requests in `UserDefaults`. Built-in requests come from `ColorData`. No spec currently documents this behavior.

## Desired Outcome

A source-grounded spec describes the current custom request lifecycle and its contract with round setup, so later playtesting changes can be checked against a clear baseline.

## Approach

Describe the implemented validation, storage, loading, and target-pool behavior using `SettingsView`, `GameViewModel`, `CustomRequestStore`, and their tests as evidence. Do not add request-management features.

## Scope

- **In**: Named request entry, hex-color validation, local persistence, loading, and exposure to the selectable request pool.
- **Out**: Round phase transitions, player controls, mixing, scoring, request deletion, synchronization, or analytics.

## Boundary Candidates

- `CustomRequestStore` owns serialization and local storage of validated custom requests.
- Settings and `GameViewModel` own request entry and selection; this spec defines their custom-request contract without owning the full round flow.

## Out of Boundary

This spec does not define how a selected target is played or scored.

## Upstream / Downstream

- **Upstream**: Existing `ColorRequest` and hex-color conversion behavior.
- **Downstream**: `round-flow-and-input` consumes available requests during setup; `color-mixing-and-scoring` consumes the selected target color through the round.

## Existing Spec Touchpoints

- **Extends**: None; no specs exist yet.
- **Adjacent**: Round setup owns target selection and phase changes; color scoring owns target comparison; `local-three-device-play` owns network-mode host/client behavior.

## Constraints

Document only current macOS/iOS app behavior and test-supported contracts. Custom requests are the only persisted game data; do not assume round history or remote storage.
