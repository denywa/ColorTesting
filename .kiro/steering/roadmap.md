# ColorGameTesting Roadmap

## Overview

Document the existing ColorGameTesting app as focused baseline specs for future playtesting changes. The app runs a three-player color-matching game on macOS and iOS. A separate `local-three-device-play` spec now covers the networked mode; this roadmap covers the shared game rules and single-device flow that predate it. The specs should describe what the current code and tests do, so the project owner can review future changes against a shared baseline.

## Approach Decision

- **Chosen**: Three feature-level specs for custom color requests, color mixing and scoring, and round flow and input.
- **Why**: These match existing responsibilities and keep persistence, color calculations, and session orchestration distinct. `GameViewModel` is the shared integration point and should be documented as such.
- **Rejected alternatives**: One whole-app spec would blur these boundaries. Four specs that separate setup from live play would add a boundary across the same view model and round lifecycle without a clear independent owner.

| Approach | Benefit | Cost | Scope |
| --- | --- | --- | --- |
| Three feature-level specs (chosen) | Clear persistence, color-rule, and session boundaries | Requires care at the shared view-model seam | Medium |
| One whole-app spec | Few documents to maintain | Mixes unrelated contracts and is harder to review | Small |
| Four specs, splitting setup from live play | Finer detail for each session stage | Duplicates ownership of round lifecycle decisions | Medium |

## Scope

- **In**: Current implemented behavior, platform-specific controls, state transitions, local request persistence, color calculations, visible results, and relevant tests.
- **Out**: New game features, gameplay redesign, analytics, playtest observation storage, the three-device local-network mode already covered by `local-three-device-play`, and implementation work not justified by a verified gap.

## Constraints

Use the current SwiftUI app and its tests as evidence. Keep the specs in English and consistent with the core steering. Treat code as the current-behavior source of truth; record any discrepancy explicitly rather than inventing behavior. These are baseline documentation specs, so generated tasks should address only confirmed documentation or implementation gaps.

The existing `local-three-device-play` spec is adjacent context. Its host/client coordination owns network-mode behavior, while this batch describes shared calculations, custom requests, and the single-device round flow. Its `GameViewModel` and view integrations are seams to reference, not duplicate ownership.

## Boundary Strategy

- **Why this split**: Request persistence and validation, color calculations, and session orchestration can be described and reviewed independently before documenting their integration.
- **Shared seams to watch**: Custom requests join the selectable target pool in `GameViewModel`. A round supplies color units, palette model, and target to the mixer and scorer. `GameViewModel` owns phase changes; color helpers and result/score views own calculations and presentation within those phases.

## Baseline Specs (completed)

- [x] custom-color-requests -- Document creation, validation, local persistence, and availability of named target requests. Dependencies: none
- [x] color-mixing-and-scoring -- Document palette-specific blending, proportions, result feedback, and match scoring. Dependencies: none
- [x] round-flow-and-input -- Document setup, three-player input, reassignment timing, and phase transitions using the other two capabilities. Dependencies: custom-color-requests, color-mixing-and-scoring

## Playtesting Part II

### Overview

Refine the three-player game using feedback from the first playtest: use RYB only, keep each player's two assigned colors distinct, offer Manual Mix and Auto Mix, require majority votes for phase actions in three-device play, and improve the full interface. Build the iOS gameplay layout from the saved sketch first, then carry the design through setup, lobby, result, and score screens.

### Approach Decision

- **Chosen**: Stage changes within the existing SwiftUI screens and shared game state, with focused updates to local-play coordination and iOS orientation configuration.
- **Why**: The current view model and local coordinator already own the related state and authority. Reusing them keeps the rule changes and visual redesign aligned across devices.
- **Rejected alternatives**: A separate iOS screen rebuild would allow more layout freedom but duplicate screen behavior and add maintenance work.

### Scope

- **In**: RYB-only play, distinct colors within each player's pair, Manual Mix and Auto Mix settings and behavior, majority three-device votes for Mix, Apply/Finish, and Redo, a modern interface across all screens, and landscape iPhone presentation alongside macOS. The attached sketch is a layout reference for the three-device gameplay screen, not a finished visual style.
- **Out**: iPad support, new mixing or scoring formulas, per-player scores, internet play, and playtest analytics or history.

### Constraints

Keep the native SwiftUI app and existing three-player game model. In one-device play, Mix, Apply/Finish, and Redo remain direct actions; voting applies only in three-device play. For three-device play, each player casts one final vote on their own device, and an action executes as soon as two players vote for it. Color contributions continue while voting is pending; the action uses the latest accepted mix. The local coordinator and synced state must carry the selected mix mode and vote state. The iOS target currently includes iPad; Playtesting Part II narrows it to iPhone and requires iPhone landscape configuration and device validation. The local `xcodebuild` command currently cannot run because the active developer directory is Command Line Tools.

### Boundary Strategy

- **Why this split**: Existing specs own color calculations, round rules, and local coordination. The new spec owns visual hierarchy, screen layouts, accessibility, and presentation of the state those specs provide.
- **Shared seams to watch**: `GameViewModel` owns mix mode and one-device transitions; `LocalPlayCoordinator` owns majority votes and shared transitions; the wire format and snapshots synchronize mode and votes; SwiftUI views display live color, vote progress, and valid actions without taking ownership of the rules.

## Existing Spec Updates

- [ ] color-mixing-and-scoring -- Remove CMYK behavior and document RYB-only result feedback, including Manual Mix proportions and Auto Mix live color without a ratio pie chart. Dependencies: none
- [ ] round-flow-and-input -- Use RYB only, ensure each player's two colors differ, add Manual Mix and Auto Mix settings and one-device transitions. Dependencies: color-mixing-and-scoring
- [ ] local-three-device-play -- Sync the mix mode and replace host-only Mix, Finish/Apply, and Redo with majority voting and shared vote progress. Dependencies: round-flow-and-input

## Direct Implementation Candidates

- None; orientation configuration and screen updates belong to the UI spec.

## Specs (dependency order)

- [ ] modern-playtest-ui -- Redesign all iPhone and macOS screens, starting with the landscape iPhone three-device gameplay layout in the saved sketch. Dependencies: color-mixing-and-scoring, round-flow-and-input, local-three-device-play

## Endless Day Run

- [x] endless-day-run — Approved integrated extension: seven editable difficulty templates and Day goals; stages 5–7 repeat after Day 7; configurable Day/client timers, 70% threshold and mistake cap; host-synchronized progress and Game Over; session-preserving Back to Settings/Lobby. Dependencies: request levels, round flow, local-play coordination and modern UI. Software checks/builds pass; physical end-to-end review remains manual.
