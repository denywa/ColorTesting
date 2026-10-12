# Implementation Plan: Custom Color Requests

Checked items record implementation verified in the current source. The only open work is a focused regression test for malformed retained data. This baseline does not introduce new request behavior.

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

- [ ] 4. Add a malformed local-storage regression test
  - In an isolated defaults suite, supply undecodable stored bytes and assert that the loaded custom catalog is empty while built-in choices remain available.
  - Supply a decodable array containing one valid request, a blank-name request, and an invalid-hex request; assert that only the valid custom request is offered with its identity and target preserved.
  - The test passes against current behavior, or exposes a concrete defect to fix before this task is checked complete.
  - _Boundary: CustomRequestStoreTests_
  - _Requirements: 3.3, 3.4, 4.1_
