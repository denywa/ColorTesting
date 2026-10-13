# Brief: color-mixing-and-scoring

## Problem

Playtesting Part II removes CMYK and adds Auto Mix. The existing baseline spec describes both palettes and only a completed Manual Mix result, so it no longer defines the color feedback players need.

## Current State

`ColorMixer` blends CMYK or RYB units after Mix. The result shows ingredient proportions, and scoring compares the result with the target through Lab and Delta E 2000. Auto Mix has no live blend yet.

## Desired Outcome

The app calculates playtest mixes from RYB only. Manual Mix keeps the result color and ingredient breakdown. Auto Mix exposes the current blended color after each accepted contribution and treats an empty bowl as empty. Both modes use the existing perceptual match score.

## Approach

Update the existing palette and mixing contracts, reuse the current RYB calculation and score, and protect the behavior with focused color tests. The round-flow spec chooses when to show Manual result or Auto score; the UI spec owns the bowl and chart presentation.

## Scope

- **In**: RYB-only color calculation, Manual ingredient proportions and result, Auto live color, and shared scoring.
- **Out**: Player assignments, timing, input, phase transitions, votes, network transport, and a new scoring formula.

## Boundary Candidates

- Color helpers calculate RYB blend, proportions, and score independently of screen rendering.
- Result and score screens present calculated values; round flow decides when those screens appear.

## Upstream / Downstream

- **Upstream**: The round supplies RYB units, mix mode, and target.
- **Downstream**: `round-flow-and-input` consumes the color values; `local-three-device-play` synchronizes them; `modern-playtest-ui` displays them.

## Constraints

Preserve the existing RYB palette identity and scoring behavior. Treat the match percentage as playtest feedback, not a physical pigment measurement.
