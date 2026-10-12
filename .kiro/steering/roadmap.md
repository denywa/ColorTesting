# Baseline Specification Roadmap

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

## Specs (dependency order)

- [x] custom-color-requests -- Document creation, validation, local persistence, and availability of named target requests. Dependencies: none
- [x] color-mixing-and-scoring -- Document palette-specific blending, proportions, result feedback, and match scoring. Dependencies: none
- [x] round-flow-and-input -- Document setup, three-player input, reassignment timing, and phase transitions using the other two capabilities. Dependencies: custom-color-requests, color-mixing-and-scoring
