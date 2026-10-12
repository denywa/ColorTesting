# Brief: color-mixing-and-scoring

## Problem

The project owner and future contributors need a stable description of the color feedback playtesters see. Blending and scoring already exist, but their rules and display responsibilities are not captured in a spec.

## Current State

`ColorMixer` blends selected color units in the chosen CMYK or RYB model. The app shows the resulting color and ingredient breakdown, then compares the result with the target through Lab color conversion and Delta E 2000 to produce a match percentage. The result screen offers redo or finish, and the score screen displays the comparison. No spec currently documents these behaviors.

## Desired Outcome

A source-grounded spec describes current mixing, proportions, result feedback, and scoring so playtest observations and future rule changes refer to the same baseline.

## Approach

Describe the existing color helpers and result/score presentation using `ColorMixer`, `ColorConverter`, `ScoreCalculator`, `ResultView`, `ScoreView`, and their tests. Treat the score as game feedback, not a physical pigment-accuracy claim.

## Scope

- **In**: Palette-specific blending, mix ratios, visible result breakdown, target comparison, match percentage, and result/score presentation.
- **Out**: Player input mapping, request persistence, timer rules, phase orchestration, or new scoring models.

## Boundary Candidates

- Color helpers own calculation and conversion rules independently of SwiftUI rendering.
- Result and score views own presentation of computed values; `GameViewModel` owns transitions into and out of those phases.

## Out of Boundary

This spec does not define who adds units to the mix or when a round changes phase.

## Upstream / Downstream

- **Upstream**: Existing palette and color-unit data, plus the round's chosen model and target.
- **Downstream**: `round-flow-and-input` invokes mixing and scoring while managing the session lifecycle.

## Existing Spec Touchpoints

- **Extends**: None; no specs exist yet.
- **Adjacent**: `custom-color-requests` defines persisted target creation; round flow defines when result and score appear; `local-three-device-play` owns networked synchronization of results and scores.

## Constraints

Describe the current implementation and tests only. Keep color math in focused helpers and preserve the app's distinction between a game score and physically accurate pigment mixing.
