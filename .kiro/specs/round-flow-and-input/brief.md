# Brief: round-flow-and-input

## Problem

Playtesting Part II changes the shared round rules: RYB is the only palette, a player cannot hold the same color twice, and groups can choose Manual Mix or Auto Mix. The baseline spec still describes palette selection and a Manual-only phase flow.

## Current State

A single-device round chooses CMYK or RYB, assigns five colors plus one duplicate across six slots, and reassigns them on a timer. Players add units to one mix, then use Mix, Redo, Finish, and New Round. The duplicate may land twice with one player. Auto Mix does not exist.

## Desired Outcome

A round always uses RYB. Each player's pair contains two distinct colors at start and after reassignment; the one repeated color belongs to two different players. Manual Mix keeps the current result step. Auto Mix updates its blended bowl after each contribution and lets players Apply to score or Redo directly during play. Manual is the default for new settings. One-device actions remain direct.

## Approach

Update the existing round state and view-model transitions, keeping calculation in `color-mixing-and-scoring` and three-device vote authority in `local-three-device-play`. Preserve the timer, targets, key routing, and saved-request behavior unless the new rule requires a change.

## Scope

- **In**: RYB-only setup, mix-mode selection and round state, distinct pairs, accepted input, timer/reassignment, and direct one-device mode-specific transitions.
- **Out**: Color formulas, request persistence, network messages, votes, separate player scores, analytics, and history.

## Boundary Candidates

- Round state and the view model own assignments, action eligibility, timing, and phase changes.
- Views forward direct one-device actions and display state; the local coordinator owns three-device votes.

## Upstream / Downstream

- **Upstream**: `custom-color-requests` supplies targets; `color-mixing-and-scoring` supplies RYB blend and score.
- **Downstream**: `local-three-device-play` synchronizes round mode and transitions; `modern-playtest-ui` presents them.

## Constraints

Keep the three-player shared mix transient and preserve macOS keyboard and iPhone touch input paths. Do not duplicate color math or vote rules in views.
