# Research & Design Decisions: Custom Color Requests

## Summary

- **Feature:** `custom-color-requests`
- **Discovery scope:** Integration-focused review of existing behavior; no new dependency or external API was investigated.
- **Guidance consulted:** `kiro-spec-design` light discovery, synthesis, principles, and review-gate rules; core project steering and the baseline roadmap.
- **Key findings:**
  - The complete local write path already exists: `SettingsView` calls `GameViewModel.addCustomRequest`, which validates and saves through `CustomRequestStore` before updating observable choices.
  - A new view model loads custom requests from device-local `UserDefaults`; `availableRequests` appends them after the built-in pool.
  - Network play transfers a selected host target as round state, while each device retains its own saved catalog. That integration belongs to `local-three-device-play`.

## Research Log

### Entry, validation, and selection

- **Context:** Determine which current behaviors the baseline must describe without extending request management.
- **Sources consulted:** `ColorGameTesting/Views/SettingsView.swift`, `ColorGameTesting/GameViewModel.swift`, `ColorGameTesting/CustomRequestStore.swift`, `ColorGameTesting/ColorData.swift`, `ColorGameTestingTests/CustomRequestStoreTests.swift`, and `ColorGameTestingTests/GameViewModelTests.swift`.
- **Findings:** The form previews valid six-digit hex input and disables Add for blank text or invalid hex. The view model trims a submitted name, rejects mutations outside settings or by a local client, saves an accepted request before publishing it, and selects its UUID. `nil` selection means Random from the combined built-in and custom list.
- **Implications:** Keep the existing view → view model → store contract. Treat round start as a consumer of the chosen target, not as request-catalog ownership.

### Local storage and failure behavior

- **Context:** Check whether local retention needs a new design or a narrowly scoped validation task.
- **Sources consulted:** `ColorGameTesting/CustomRequestStore.swift`, `ColorGameTestingTests/CustomRequestStoreTests.swift`, and `.kiro/steering/tech.md`.
- **Findings:** The existing store uses a Codable array of UUID, text, and hex records under `customColorRequests.v1` in injectable `UserDefaults`. Missing or undecodable data yields no custom requests; decoded records with blank names or invalid hex are filtered. Existing tests cover valid persistence and input rejection but do not exercise corrupted payloads or invalid decoded records.
- **Implications:** Preserve the store and record format. The only identified open implementation task is a focused malformed-storage regression test; production changes depend on that test exposing a defect.

### Adjacent specification boundary

- **Context:** Avoid claiming network catalog ownership or full round-flow ownership in this baseline.
- **Sources consulted:** `.kiro/steering/roadmap.md`, `.kiro/specs/custom-color-requests/brief.md`, `.kiro/specs/local-three-device-play/requirements.md`, `.kiro/specs/local-three-device-play/design.md`, and `ColorGameTestingTests/LocalGameSnapshotMapperTests.swift`.
- **Findings:** The network spec owns host/client coordination and target snapshot transfer. Its tests confirm that a host-selected custom target can appear on a client without populating the client's local custom catalog.
- **Implications:** Define the local catalog and setup-choice seam here. Revalidate the downstream network snapshot if the target contract changes.

## Architecture Pattern Evaluation

| Option | Strength | Limit | Decision |
| --- | --- | --- | --- |
| Existing SwiftUI view → observable view model → local store | Already implements the scoped behavior and matches steering | Requires explicit care at round and network seams | Retain |
| New repository or synchronization layer | Could support future storage or sharing | Adds an abstraction and behavior absent from this baseline | Do not introduce |

## Design Decisions

### Decision: Keep one local catalog path

- **Context:** Entry, retention, and target availability are variants of one custom-request lifecycle.
- **Selected approach:** Document the existing `ColorRequest` value, `ColorHex` converter, `GameViewModel` coordinator, and `CustomRequestStore` without adding a second model or adapter.
- **Rationale:** This is the smallest design that matches observed code and the project's responsibility-based structure.
- **Trade-off:** It records a device-local catalog only; editing, deletion, and synchronization remain outside scope.
- **Follow-up:** Recheck the round setup consumer if the available-list or selected-ID contract changes.

### Decision: Use current platform storage

- **Context:** Custom requests are the only persisted game data in the current app.
- **Selected approach:** Retain the existing Codable records in `UserDefaults` and injectable defaults for tests.
- **Rationale:** No new dependency or migration is needed for a baseline of implemented behavior.
- **Trade-off:** Failed writes currently leave the form open without a dedicated error message; this is recorded behavior rather than a new UI requirement.
- **Follow-up:** Add malformed-storage regression coverage before changing load behavior.

## Risks & Mitigations

- **Untested retained-data failures:** Add a regression covering undecodable bytes and decoded invalid records in an isolated defaults suite.
- **Boundary drift:** Recheck `round-flow-and-input` and `local-three-device-play` when request identity, target representation, or selection semantics change.

## References

- `.kiro/steering/product.md`, `tech.md`, `structure.md`, and `roadmap.md` — project intent, stack, layout, and spec boundaries.
- `.kiro/specs/custom-color-requests/brief.md` — scope and upstream/downstream context.
- `.kiro/specs/local-three-device-play/requirements.md` and `design.md` — adjacent network-mode ownership.
- `ColorGameTesting/Views/SettingsView.swift`, `GameViewModel.swift`, `CustomRequestStore.swift`, and `ColorData.swift` — current implementation evidence.
- `ColorGameTestingTests/CustomRequestStoreTests.swift`, `GameViewModelTests.swift`, and `LocalGameSnapshotMapperTests.swift` — current verification evidence and identified gap.

---

## Implementation Gap Validation (2026-10-12)

### Analysis Summary

- All four requirement groups have an implementation path in the current source; no production behavior is confirmed missing.
- The unchecked task 4 is a real test gap: malformed retained data and invalid decoded records are handled by `CustomRequestStore.load` but lack direct regression coverage.
- Client-authority rejection and Random selection from a catalog containing custom requests are implemented, but direct focused tests for those cases were not found. No tests were run for this validation.

### Requirement-to-Asset Map

| Criteria | Existing assets | Status |
| --- | --- | --- |
| 1.1–1.4 | `SettingsView` provides the picker, Add sheet, fields, preview, and submission gating; `ContentView` routes eligible setup. | Implemented |
| 2.1–2.4 | `ColorHex` parses six-digit hex input; `GameViewModel.addCustomRequest` trims names and guards phase and local authority. | Implemented; direct client-rejection test not found |
| 3.1–3.4 | `CustomRequestStore` saves and loads records through injectable `UserDefaults`, rejects undecodable data, and filters invalid records. | Implemented; malformed-storage regression missing |
| 4.1–4.4 | `GameViewModel.availableRequests` combines built-in and custom targets; addition selects the new ID; round setup resolves an ID or chooses from the combined pool. | Implemented; direct Random-with-custom test not found |

### Integration and Constraints

The existing path is `SettingsView → GameViewModel → CustomRequestStore`. The round-flow spec owns target resolution at round start. The local-network spec owns transmission of a host-selected target as round state, without copying the host's saved catalog to clients. No new package, API, migration, or storage layer is required. The existing spec metadata has all approvals set to true while `ready_for_implementation` is false; this is a metadata inconsistency, not a runtime behavior gap.

### Implementation Options

| Option | Work | Trade-off |
| --- | --- | --- |
| A — Extend existing tests | Add malformed-payload and invalid-record cases to `CustomRequestStoreTests`. | Smallest change; preserves current storage design. |
| B — New corruption test file | Isolate those cases in another XCTest file. | Clear grouping, but adds a file for a narrow concern. |
| C — Test, then repair if needed | Add the cases, and change the store only if a test exposes a defect. | Safest conditional route; production work is not justified yet. |

**Effort and risk:** S (1–3 days), Low for the verified test gap. The store is injectable and the relevant behavior is local. Prefer A, with C only if the new test fails. Additional focused authority and Random-selection checks would improve evidence but are not confirmed behavior gaps.

### Research Needed and Next Validation

No external dependency research is needed. Run the focused XCTest target before claiming that the retained-data handling passes. Keep the new test within the custom-request boundary and recheck round setup and network snapshots if request identity or target representation changes.

## Difficulty-Level Extension

Requirements approved by the user after reviewing difficulty-levels-proposal.md. Minimal integration discovery used the current ColorData, CustomRequestStore, GameViewModel, settings and existing request tests. Consulted kiro-spec-design principles, light discovery, synthesis and review gate, plus core steering.

- Preserve availableRequests as the full catalog to keep existing callers/tests compatible; add a filtered consumer for setup and confirmSettings.
- Keep the storage key and add an optional integer level; legacy records default to Level 1. Validate unknown values per record rather than decoding an enum that could discard the whole array.
- Keep level selection outside the GameState reset so repeated New Round testing retains the level.
- No wire change is needed: this version uses difficulty only for host/local catalog selection, and keeps target ID/text/color transfer unchanged. Client gameplay does not display difficulty metadata.
- Reuse Foundation/SwiftUI and existing components; no additional storage layer or dependency is justified.
- Inline design review passed: all 25 criteria explicitly mapped, concrete files/contracts supplied, boundaries and migration failure behavior checked. Implementation plan is included for human review; formal tasks await design approval.
