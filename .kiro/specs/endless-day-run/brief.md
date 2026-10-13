# Brief: Endless Day Run

Status: combined requirements/design/implementation plan approved and implemented. Software checks pass; real-device review is manual.

## Problem

The current game returns to settings after each scored request. The developer wants continuous playtesting across Days until the group fails, with adjustable request difficulty schedules, targets, time limits and mistake limits.

## Current State

Three request levels and level-aware local custom requests are implemented. GameViewModel owns a single active request and Manual/Auto transitions. LocalPlayCoordinator owns two-vote majority decisions, host authority, pause/recovery and snapshots. The existing countdown changes player colors; it is separate from the requested Day/customer deadlines.

## Desired Outcome

Configure a run once, complete customer requests to pass Days, and progress endlessly without repeated setup. A customer/client means one target request, not a player device. Request difficulty remains Levels 1–3.

## Confirmed Rules

- Seven editable difficulty stages, with initial request sequences below.
- Default completion target: three successful requests per Day; configurable for each stage/Day template. Each configured request slot has a selected difficulty.
- After stage 7, repeat stages 5, 6 and 7 indefinitely while the visible Day number increases.
- Day Timer default: ten minutes; configurable.
- Client Timer default: three minutes per customer/request; configurable. Proposed as alternative modes in plan.md; Client timeout adds one mistake and Day timeout with an unfinished target ends the run.
- Maximum mistakes per Day defaults to three, with an unlimited option. Reaching the third mistake ends the run in either timer mode.
- Minimum successful score is configurable, default 70 percent. Below-threshold scores count as mistakes and continue to a new target at the current level.
- Day timeout with unfinished goals ends the run; Client timeout counts as a mistake.
- Continue advances without setup. Gameplay Back to Settings/Lobby replaces End Session and preserves the local group.
- Current RYB mixing, per-player distinct colors, Manual/Auto modes, local catalogs and majority votes remain available.

## Default Schedule

| Day/template | Request levels |
| --- | --- |
| 1 | 1–1–1 |
| 2 | 1–1–2 |
| 3 | 1–2–2 |
| 4 | 1–2–3 |
| 5 | 2–2–3 |
| 6 | 2–3–3 |
| 7 | 3–3–3 |
| 8 onward | Reuse templates 5–6–7 repeatedly |

Source: the user supplied this schedule image and explicitly requested its defaults. The image’s descriptive difficulty captions are reference context, not additional game rules.

## Proposed Approach

A cohesive endless-run domain holds configuration, Day progress, customer completion, deadlines and mistakes. Integrate it with existing round actions and authoritative host snapshots; views render state and forward actions. Preserve the current color-reassignment clock as a separate concern. Use grouped implementation and focused checks under the efficient workflow requested by the user.

## Scope

- **In:** Seven-stage configuration, repeating schedule, target selection from configured request levels, completion/failure decisions once clarified, two timer modes, daily mistake reset/limit, progress and game-over screens, solo and local-session integration.
- **Out:** New request copywriting/colors, altered pigment/scoring formulas, internet play, accounts, run history or persistence after closing the app unless later requested.

## Boundary Candidates

- Endless-run configuration/progression/deadline domain.
- Integration with GameViewModel’s current request lifecycle and action eligibility.
- LocalPlayCoordinator/mapper/protocol integration for host-owned progress, clocks, pause/reconnect and shared transitions.
- Settings and gameplay/result/game-over presentation.

## Existing Spec Touchpoints

- **Depends on:** custom-color-requests difficulty filtering and saved catalogs.
- **Integrates with:** round-flow-and-input lifecycle and separate reassignment clock.
- **Integrates with:** local-three-device-play authority, votes and synchronized state.
- **Adjacent:** color-mixing-and-scoring calculation and modern-playtest-ui styling.

## Clarified Rules and Proposed Details

The user confirmed the core scoring, timeout and mistake rules above. plan.md makes the remaining lifecycle details explicit for approval: new clients receive fresh budgets; Day time runs through unfinished feedback; Client time stops when graded; time pauses for connection loss; host Continue/Restart/Back actions preserve group authority. The user approved these details together in plan.md; implementation uses grouped changes and focused checks.

## Request rotation update

Each difficulty level uses a shuffled queue containing its built-in and custom requests. Showing a client consumes that request, including clients that later fail or time out. A level repeats only after every request in its pool has appeared. Queues survive Day transitions and reconnects, and reset for a new run. Avoid consecutive repeats between cycles when alternatives exist. The host owns selection; clients receive the chosen request through snapshots.
