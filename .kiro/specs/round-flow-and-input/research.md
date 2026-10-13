# Research & Design Decisions: Playtesting Part II

## Summary

- **Feature:** round-flow-and-input
- **Discovery Scope:** Extension; light analysis of state, input, timer, views and adjacent contracts.
- **Key Findings:** Existing four-phase controller is reusable. No MixMode/currentBlend or Auto Apply currently exists. Allocation permits same-player duplicates; both initial allocation and reassignment must share a corrected invariant.

## Research Log

### Shared controller and live color

- **Context:** Add Auto while keeping Manual and staged SwiftUI implementation.
- **Sources Consulted:** GameModels.swift, GameState.swift, GameViewModel.swift, GameViewModelFlowTests.swift and GameViewModelLocalPlayTests.swift.
- **Findings:** Solo addColor and authoritative acceptColor both append units. Clients apply snapshots and do not calculate. Existing result-phase guards/timer hooks provide the Manual path.
- **Implications:** Add MixMode, immutable Round.mixMode, Manual setup default and currentBlend separate from frozen mixResult. Use one accepted-unit helper for both append paths. Store live color in GameState so client apply does not require a separate override/cache or calculation. Auto goes playing→score, preserving four phases.

### Pair uniqueness and call sites

- **Sources Consulted:** randomAssignments in GameViewModel.swift; GameViewModelTests.swift, KeyRouter.swift, SettingsView.swift, GameView.swift, ResultView.swift and ContentView.swift.
- **Findings:** Five palette colors plus one duplicate fill six slots. A duplicated adjacent pair is possible, and a test currently explicitly requires that case. At most one pair conflicts; a bounded swap with another pair preserves all-five-plus-one counts. Physical keys and touch mapping need no redesign.
- **Implications:** Correct allocation once for both start/reassignment; replace contradictory duplicate test and add deterministic conflict fixture. Remove model-selection gating; preserve target/duration/hint/catalog behavior and solo platform controls.

## Architecture Pattern Evaluation

| Option | Strength | Limit | Decision |
| --- | --- | --- | --- |
| Extend GameViewModel/shared views | One state/transition authority | Shared file staging required | Selected |
| Separate Auto/iOS controller | Layout freedom | Duplicate rules/timer/snapshot seams | Rejected |

## Design Decisions

- **Generalization:** Both modes use the same round aggregate, four phases and guarded actions; mode determines eligible transitions. Eligibility is shared by views/coordinator, while voting remains network-only.
- **Build vs. adopt:** Reuse Foundation Timer, AppKit keys, SwiftUI controls, math and catalog. No dependency or new platform API.
- **Simplification:** Add one enum, optional live field, eligibility properties and Auto action to existing files. Keep exact two modes and no timer service or generic action framework. Store live color once for wire mirroring instead of computed client color.
- **Boundary:** Round owns GameState/transitions; color owns formulas; network owns pause/seat/vote gates and codec; modern UI owns layout/orientation. Run shared-file edits sequentially after color declarations.
- **Skills consulted:** kiro-spec-design light discovery/synthesis/review and active Ponytail full; kiro-verify-completion for evidence limits.

## Risks & Mitigations

- Auto missed on host input: test both solo and accepted network append paths.
- Wrong action or stale result: explicit phase/mode/empty/lock guards, separate currentBlend/mixResult and empty/reset tests.
- Timer/persistence regression: preserve Redo countdown and custom catalog, and test every New Round resets Manual but retains duration/hint/catalog.
- Existing UI contract task is blocked: unblock only after shared eligibility/currentBlend and network voting exist.

## Review Gate

All 39 numeric criteria appear in traceability. Mechanical checks verified populated sections, existing concrete paths, requirements approval and no placeholders. Bounded review repaired an absent explicit Data Models section. Judgment checked state ownership, mode flows, both input paths, distinct-pair invariants, client apply and executable staged integration. No source implementation or runtime verification occurred.

## References

Production/test files named above and core steering are local sources. Adjacent color/network/UI designs define the integration boundaries. Historical baseline research below predates this scope and is retained for audit context.


---

## Historical Research (superseded baseline scope)

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
