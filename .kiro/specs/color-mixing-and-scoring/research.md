# Research and Design Decisions: Color Mixing and Scoring

## Summary

- **Feature**: `color-mixing-and-scoring`
- **Discovery Scope**: Extension-style light discovery of an existing baseline; no new feature or dependency was proposed.
- **Key Findings**:
  - `ColorMixer` averages each unit in the selected model's native component space, with a stored-sRGB identity path for one distinct color.
  - `Mix.ratios`, `ResultView`, `ColorConverter`, `ScoreCalculator`, and `ScoreView` already separate ingredient feedback from score calculation and presentation.
  - `GameViewModel` is the existing invocation and phase seam; network coordination and request persistence have separate specification ownership.

## Research Log

### What values does the round give to the mixer and scorer?
- **Context**: Establish the calculation inputs and the boundary with round flow.
- **Sources Consulted**: `.kiro/specs/color-mixing-and-scoring/brief.md`; `ColorGameTesting/GameModels.swift`, `GameState.swift`, `ColorData.swift`, and `GameViewModel.swift`; `ColorGameTestingTests/GameViewModelFlowTests.swift`.
- **Findings**:
  - `Round` holds the selected model, target request, and mix; `Mix` holds contributed `ColorUnit` values.
  - `pressMixButton()` requires a nonempty, unlocked mix in the playing phase before storing a result. `selectFinish()` converts the stored result and target to Lab before storing a percentage.
  - Phase transitions, input, locking, and redo remain view-model responsibilities.
- **Implications**: This spec can define calculation and display contracts without taking ownership of the round lifecycle. `GameViewModel` remains an integration seam.

### How are mix color and ingredient proportions calculated?
- **Context**: Record the existing baseline precisely enough to distinguish later rule changes.
- **Sources Consulted**: `ColorGameTesting/ColorMixer.swift`, `GameState.swift`, `Views/ResultView.swift`; `ColorGameTestingTests/ColorMixerTests.swift`, `MixRatiosTests.swift`, and `ResultViewTests.swift`.
- **Findings**:
  - A mix with one distinct color ID returns that color's stored sRGB. A mixed-ID CMYK or RYB mix averages every unit's native component vector, then converts to sRGB; calculated channels are clamped.
  - `Mix.ratios` counts units by color ID and divides by total units. An empty mix returns no ratios.
  - The result breakdown keeps first-contribution order, exact counts, and separately rounded one-decimal percentages.
  - The current working tree has uncommitted changes in `ColorMixer.swift` and `ColorMixerTests.swift`; this log records that version as the inspected baseline.
- **Implications**: Keep the model-specific color calculation in `ColorMixer`, proportions in `Mix`, and formatted rows in `ResultView`. Later changes to the uncommitted mixer work require revalidation.

### How does the match percentage reach the player?
- **Context**: Separate perceptual distance, game calibration, and visible score formatting.
- **Sources Consulted**: `ColorGameTesting/ColorConverter.swift`, `ScoreCalculator.swift`, `Views/ScoreView.swift`, and `GameViewModel.swift`; `ColorGameTestingTests/ColorConverterTests.swift`, `ScoreCalculatorTests.swift`, `ScoreViewTests.swift`, and `GameViewModelFlowTests.swift`.
- **Findings**:
  - The view model converts result and target sRGB to Lab. `ScoreCalculator` computes Delta E 2000 and applies a nonlinear game score capped at distance 100, with 100 percent for identical Lab inputs and 0 percent at or above the cutoff.
  - `ScoreView` formats the percentage to two decimal places, explains that higher is closer, and places the mix and target swatches side by side when both colors exist.
  - Focused XCTest source files contain calculation, reference-pair, integration, and rendering assertions. A passing test execution was not verified in this spec run: `xcodebuild` reached compilation with Xcode selected and writable derived data, then failed when the sandbox disrupted the Observation macro plugin.
- **Implications**: Preserve the distinction between Delta E distance and the game-calibrated percentage. Treat the test files as source evidence, not a fresh passing test result.

### Which neighboring specs own shared behavior?
- **Context**: Prevent duplicate ownership at the shared view-model and result/score views.
- **Sources Consulted**: `.kiro/steering/roadmap.md`, `.kiro/specs/local-three-device-play/design.md`, `.kiro/specs/color-mixing-and-scoring/brief.md`, and core steering files.
- **Findings**:
  - `round-flow-and-input` owns who contributes units and when the app enters result or score.
  - `custom-color-requests` owns target creation and persistence.
  - `local-three-device-play` owns host/client coordination and network-mode presentation.
- **Implications**: This design documents the shared calculation and single-device result/score presentation, while using those adjacent specs only as contracts at their seams.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Decision |
| --- | --- | --- | --- | --- |
| Retain focused helpers and views | `Mix`, `ColorMixer`, `ColorConverter`, and `ScoreCalculator` calculate; views present; `GameViewModel` invokes | Matches current code, tests, and steering boundaries | Shared view-model and views require clear spec ownership | Selected |
| Move calculations into `GameViewModel` | Combine lifecycle and color rules | Fewer files in isolation | Blurs the existing domain and phase boundary; no baseline need | Rejected |
| Add a color package or adapter | Replace existing math with another implementation | Could support a future scoring redesign | Adds a dependency and changes playtest rules without a requirement | Rejected |

## Design Decisions

### Decision: Keep the existing calculation and presentation split
- **Context**: The baseline describes implemented behavior rather than a new architecture.
- **Alternatives Considered**: Retain focused helpers and views; consolidate color rules in the view model.
- **Selected Approach**: Preserve the current value types, color helpers, and SwiftUI result/score views, with `GameViewModel` as the invocation seam.
- **Rationale**: Each current responsibility has a direct source file and focused test evidence. Consolidation would expand phase ownership into color rules.
- **Trade-offs**: The seam spans several small files, so the design records their contracts and traceability explicitly.
- **Follow-up**: Recheck the seam when `round-flow-and-input` or `local-three-device-play` changes shared state.

### Decision: Reuse current color math and platform facilities
- **Context**: Synthesis checked whether a broader interface, external package, or new adapter was necessary.
- **Alternatives Considered**: Existing Swift/Foundation math and SwiftUI formatting; new package or abstraction.
- **Selected Approach**: Reuse existing code and platform APIs. The common concern is a color comparison pipeline, but no new generalized interface or implementation is needed for this baseline.
- **Rationale**: No new behavior, external API, or dependency was requested. The existing test files describe the current calculation choices.
- **Trade-offs**: The game-calibrated score remains specific to this app; it is not a physical pigment or universal similarity standard.
- **Follow-up**: Evaluate alternatives only if a future requirement changes the game rules.

## Risks & Mitigations

- **Uncommitted mixer changes may move the baseline** — Reinspect `ColorMixer.swift` and its tests before using this spec to judge a later implementation.
- **A game percentage can be mistaken for physical mixing accuracy** — Keep the design and score presentation explicit that it is calibrated feedback from perceptual distance.
- **Test execution is unverified in this environment** — Rerun the focused macOS scheme in an Xcode environment where the Observation macro plugin can run before claiming a passing suite.

## References

- `.kiro/steering/product.md`, `tech.md`, `structure.md`, and `roadmap.md` — product purpose, current stack, file responsibilities, and spec boundaries.
- `.kiro/specs/color-mixing-and-scoring/brief.md`, `requirements.md`, and `design.md` — discovery scope and the resulting baseline contracts.
- `.kiro/specs/local-three-device-play/design.md` — adjacent network-mode ownership.
- `.agents/skills/kiro-spec-design/rules/design-discovery-light.md`, `design-synthesis.md`, and `design-review-gate.md` — consulted discovery, simplification, and review guidance.
- The source and XCTest files listed above — direct evidence from the current working tree. No external web source or library investigation was used.

---

## Implementation Gap Validation (2026-10-12)

### Analysis Summary

- Current source implements all color-mixing, ingredient, result, and score acceptance criteria; no missing runtime capability was confirmed.
- The baseline includes uncommitted changes to `ColorMixer.swift` and `ColorMixerTests.swift`, including the RYB neutral path. Later review must use the same source state or revalidate the calculation contract.
- This validation inspected source and test assertions but did not run tests. The earlier research log records a sandboxed Xcode failure; a later focused macOS run passed for mixer, converter, and score-calculator tests before the repository moved to `Documents/Academy`.

### Requirement-to-Asset Map

| Criteria | Existing assets | Status |
| --- | --- | --- |
| 1.1–1.4 | `ColorMixer` returns stored sRGB for one distinct color, averages CMYK or RYB native components by unit, converts, and clamps calculated channels; `ColorMixerTests` covers these paths. | Implemented |
| 2.1–2.3 | `Mix.ratios` calculates counts over total units, including the empty case; `ResultView.breakdown` preserves first-contribution order and formats one-decimal percentages. | Implemented |
| 3.1–3.2 | `ResultView` displays the swatch and breakdown when data exists and a no-result state otherwise. | Implemented; fallback has limited direct test evidence |
| 4.1–4.6 | `GameViewModel` converts result and target to Lab; `ScoreCalculator` applies Delta E 2000 and game calibration; `ScoreView` formats the percentage, explanation, swatches, and no-score state. | Implemented; missing-state and swatch pairing have limited direct test evidence |

### Integration and Constraints

`Round` supplies units, color model, and target. `GameViewModel` invokes the pure calculation helpers and owns phase changes; result and score views present computed values. The round-flow spec owns Mix and Finish action gates, and `local-three-device-play` owns network synchronization. `ColorMixer` expects palette colors to carry components for the selected model; the one-color identity path trusts the stored sRGB value. Built-in palette data meets these assumptions. No new dependency or external API is needed. All tasks are checked as baseline work, yet `ready_for_implementation` is false in `spec.json`; this metadata flag does not indicate a missing runtime feature.

### Implementation Options

| Option | Work | Trade-off |
| --- | --- | --- |
| A — Retain existing helpers and views | Reuse `Mix`, `ColorMixer`, `ColorConverter`, `ScoreCalculator`, and SwiftUI views; add focused checks only when a concrete evidence gap matters. | Smallest path and current ownership stays clear; shared view-model seam still needs review after rule changes. |
| B — New calculation or presentation component | Move stable behavior behind another abstraction. | Could isolate a future redesign, but adds migration and duplicate contracts without a current gap. |
| C — Conditional focused extraction | Keep pure math and extract only a presenter or adapter if a later requirement creates a distinct responsibility. | Limits churn now, while retaining an upgrade path; requires integration tests when used. |

**Effort and risk:** No runtime implementation work is currently justified. Focused verification is S (1–3 days), Low risk; a new component would be M (3–7 days), Medium risk because it changes established seams. Prefer A for the current baseline.

### Research Needed and Next Validation

No external research is needed. Re-run focused macOS tests after any change to the uncommitted mixer work. If the result or score fallback becomes a release gate, add direct rendering assertions; source inspection alone is not a passing test result.
