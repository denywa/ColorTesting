# Research Log: Round Flow and Input

## Summary

Light, integration-focused discovery inspected the current working tree, core steering, this feature's brief, both completed upstream specs, the adjacent `local-three-device-play` spec, and existing Swift source and tests. This is a baseline of implemented single-device behavior, with no new library, component, or runtime prerequisite.

## Research Log

### Round ownership and shared phase seam

- **Sources**: `GameViewModel.swift`, `GameState.swift`, `GameModels.swift`, `ContentView.swift`, `GameViewModelFlowTests.swift`, `ContentViewTests.swift`.
- **Finding**: `GameViewModel` owns the four phases and guarded transitions. `ContentView` routes a selected single-device session to the phase screen; mode selection itself belongs to `local-three-device-play`. A network client can apply a host snapshot to the same state shape, but the host/client protocol is outside this spec.
- **Implication**: Document `settings → playing → result → score → settings` as the shared phase contract and detail only direct single-device actions here.

### Request and calculation dependencies

- **Sources**: `custom-color-requests` requirements/design/tasks, `color-mixing-and-scoring` requirements/design/tasks, `GameViewModel.swift`.
- **Finding**: The request spec supplies `availableRequests` and `selectedRequestID`; the calculation spec supplies `ColorMixer.blend` and `ScoreCalculator.matchPercentage`. The view model resolves a target at round start, invokes blending on Mix, and invokes scoring on Finish.
- **Implication**: This design owns the action gates and phase handoff, not catalog validation/storage, blend math, ratio math, result breakdown, or score presentation details.

### Input, assignments, and timer

- **Sources**: `SettingsView.swift`, `GameView.swift`, `KeyRouter.swift`, `GameViewModel.swift`, `GameViewModelTests.swift`, `KeyRouterTests.swift`, `GameViewRenderingTests.swift`.
- **Finding**: Each five-color palette fills six randomized slots with exactly one duplicated color. macOS maps Q/W, B/N, O/P to player slots; iOS displays six touch buttons. A one-second Foundation timer reassigns at zero without clearing units. Mix locks the round and stops the timer; Redo resumes from the stored remaining count.
- **Implication**: Reuse the existing view-model state and platform controls. No input abstraction or timer service is needed.

## Architecture Pattern Evaluation

The existing SwiftUI view → main-actor view model → value state/helper pattern covers every requirement. Splitting timing, keyboard routing, or phase ownership into new components would add a second authority with no baseline need. The network coordinator consumes this pattern without changing single-device ownership.

## Design Decisions and Synthesis

- **Generalization**: The phase/state contract is shared by single-device and network displays, but the only behavior specified here is direct single-device mutation. No new generalized session interface is introduced.
- **Build vs. adopt**: Existing Foundation `Timer`, AppKit local key monitor, SwiftUI buttons, and current domain helpers provide the behavior. No dependency is added.
- **Simplification**: Keep lifecycle transitions in `GameViewModel`; keep views as action forwarding and rendering; use `KeyRouter` only for macOS physical key mapping.

## Risks and Validation Focus

- `GameViewModel` is shared with network mode. A future phase, input, or assignment change must recheck `local-three-device-play` snapshots and authority gates.
- The current test files cover the principal state paths and macOS key mapping. The iOS scheme has no test action; iOS touch behavior is source-inspected rather than supported by a passing device test in this spec run.
- Test presence is evidence of implementation coverage, not evidence of a passing suite. The spec generation did not run the full Xcode test suite.

---

## Implementation Gap Validation (2026-10-12)

### Analysis Summary

- The current source contains all five requirement groups for the single-device round; no missing runtime behavior was confirmed.
- Existing XCTest files assert the principal state transitions, assignments, timer, key routing, and views, but this validation did not run them.
- iOS touch wiring is visible in source, while the iOS scheme has no test action. Shared `GameViewModel` changes also need revalidation of the separate three-device snapshot and authority contracts.

### Requirement-to-Asset Map

| Criteria | Existing assets | Status |
| --- | --- | --- |
| 1.1–1.6 | `SettingsView` presents model, target, duration, and hint controls; `GameViewModel` holds defaults, guards Start, and resolves an explicit or Random target. | Implemented |
| 2.1–2.5 | `GameState` defines one shared `Round` and `Mix`; `GameViewModel` creates the round and six assignments; `GameView` presents target, players, mix, countdown, and optional hint. | Implemented |
| 3.1–3.5 | `GameModels` and `KeyRouter` define macOS key pairs; `GameView` provides iOS touch buttons; `GameViewModel.addColor` guards phase and appends one unit. | Implemented; iOS device execution unverified |
| 4.1–4.5 | `GameViewModel` schedules one-second ticks, reassigns six slots at zero, retains mix units, and guards nonplaying or locked states. | Implemented |
| 5.1–5.7 | `GameViewModel` guards Mix, Redo, Finish, and New Round; `ContentView` routes phases; result and score views forward actions. | Implemented |

### Integration and Constraints

This spec owns direct single-device mutations and phase transitions. `custom-color-requests` supplies the selectable target catalog; `color-mixing-and-scoring` supplies calculated result and score values. `local-three-device-play` owns mode selection, host/client permissions, snapshots, and network routing, while sharing the underlying phase and round shapes. A change to `GameViewModel` phase, input, timer, or assignment state must recheck `LocalPlayCoordinator` and `LocalGameSnapshotMapper`. No new runtime, library, or configuration is required. The spec has approved tasks that are all checked, although `ready_for_implementation` remains false in metadata; that flag is inconsistent with approvals but is not a behavior gap.

### Implementation Options

| Option | Work | Trade-off |
| --- | --- | --- |
| A — Extend current components | Keep phase ownership in `GameViewModel` and platform controls in their existing views and `KeyRouter`. | Smallest future change and aligned with steering; view-model size can grow. |
| B — New round controller or input abstraction | Split timing and transitions into a new authority. | Could isolate a future large feature, but adds synchronization and ownership seams without a current gap. |
| C — Conditional extraction | Preserve one view-model authority, extracting only a responsibility that demonstrably grows. | Avoids premature refactoring; needs seam tests if later used. |

**Effort and risk:** No runtime implementation task is justified by the current requirements. Validation work is S (1–3 days), Low risk. A new controller would be M (3–7 days), Medium risk because of the shared network-mode contract. Prefer A for the baseline.

### Research Needed and Next Validation

No external research is needed. Run the macOS flow, model, and key-routing tests before claiming a passing suite. Validate the six iOS touch controls on a supported device or simulator, since the current iOS scheme has no test action. Recheck host/client snapshots if shared round fields or transition rules change.
