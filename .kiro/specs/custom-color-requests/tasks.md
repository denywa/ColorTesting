# Implementation Plan: Custom Color Requests

Checked items record implementation verified in the current source. The baseline is extended by the approved difficulty-level implementation plan below. Execute the extension as grouped changes with focused validation, as requested by the user.

- [x] 1. Preserve custom request entry in settings
  - The settings picker exposes Add; its sheet contains name and hex fields, Cancel and Add, a normalized color preview, and a disabled Add action for blank or invalid input.
  - The existing settings UI presents these controls only where local setup is allowed.
  - _Boundary: SettingsView_
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Integrate validation with local request persistence
  - The current request action trims names, accepts only six-digit hex targets, rejects invalid or unauthorized calls without changing the catalog, and saves accepted requests before publishing them.
  - A successful addition is visible in the current catalog and becomes the selected target choice; a rejected addition returns failure without that state change.
  - _Boundary: GameViewModel, ColorHex, CustomRequestStore_
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 4.2_

- [x] 3. Integrate the retained catalog with the round-setup choice seam
  - The existing load path preserves valid request identity, text, and color while omitting invalid retained records or an undecodable payload.
  - The setup choice exposes built-in and custom targets plus Random. `round-flow-and-input` task 1.2 reads this catalog and choice to resolve explicit or Random targets at round start.
  - _Boundary: CustomRequestStore, GameViewModel catalog and selection state_
  - _Requirements: 3.2, 3.3, 3.4, 4.1, 4.3, 4.4_

- [x] 4. Add a malformed local-storage regression test
  - In an isolated defaults suite, supply undecodable stored bytes and assert that the loaded custom catalog is empty while built-in choices remain available.
  - Supply a decodable array containing one valid request, a blank-name request, and an invalid-hex request; assert that only the valid custom request is offered with its identity and target preserved.
  - The test passes against current behavior, or exposes a concrete defect to fix before this task is checked complete.
  - _Boundary: CustomRequestStoreTests_
  - _Requirements: 3.3, 3.4, 4.1_

## Approved Difficulty-Level Extension

User approved the design and three-step implementation plan, and requested the efficient workflow: grouped implementation, focused checks, no separate reviewers or per-task commits. Inline task-graph check: PASS; persistence precedes selection/UI integration, followed by validation.

- [x] 5. Add and integrate request difficulty levels
- [x] 5.1 Classify requests and preserve level-aware saved data
  - Add three typed levels; classify the existing seven requests without changing IDs/text/targets.
  - Save a custom request’s level and load legacy records as Level 1; skip invalid records individually.
  - Done when all three pools are nonempty and save/reload/legacy/invalid-data checks pass.
  - _Boundary: ColorData, CustomRequestStore and their tests_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 5.1, 5.5, 5.6_
- [x] 5.2 Integrate level selection with setup, entry and round start
  - Add settings/form selectors; filter choices and Random by level, clear incompatible choices, and select a newly saved request in its level.
  - Retain the level for New Round and preserve solo/host authority and target transfer.
  - Done when each level starts only its own requests and unauthorized changes are rejected.
  - _Boundary: GameViewModel/SettingsView explicit catalog-to-round integration_
  - _Depends: 5.1_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 4.1, 4.2, 4.3, 4.4, 5.2, 5.3, 5.4, 5.5, 5.7, 5.8, 5.9_
- [x] 5.3 Validate persistence, selection and both platforms
  - Run focused catalog/setup/authority checks and build macOS/iOS; keep existing gameplay and network contracts intact.
  - Done when focused checks and both builds succeed, including legacy records and retained New Round selection.
  - _Boundary: Request/setup/authority tests and Xcode integration_
  - _Depends: 5.1, 5.2_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9_

## Implementation Evidence

The approved extension was implemented as one grouped change without separate reviewers or commits, at the user’s request. RequestDifficultyTests covers classification, per-level Random/explicit selection, filtering, save/reload, legacy and invalid records, New Round retention and authority. Existing catalog/setup/authority tests were also run: 33 passed, zero failed/skipped. The macOS test build and iOS Simulator build succeeded. Logs: `/private/tmp/request-levels-focused.log`, `/private/tmp/request-levels-ios.log`. Full-suite and physical-device interaction checks were not repeated. Baseline malformed-storage task 4 is covered by RequestDifficultyTests.testLegacyAndInvalidStoredRecordsPreserveValidNeighbors.
