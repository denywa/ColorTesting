# Research and Design Decisions: modern-playtest-ui

## Summary

- **Feature**: `modern-playtest-ui`
- **Discovery Scope**: Extension; light integration discovery.
- **Key Findings**:
  - Existing SwiftUI screens already cover the complete game flow and split one-device from three-device controls; presentation can evolve in place.
  - Manual/Auto mix mode and three-device vote state are absent from current public state. The UI must consume contracts added by the adjacent rule and local-play specs.
  - The iOS target currently includes iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). The owner narrowed scope to iPhone and macOS; the iOS target must become iPhone-only and advertise landscape orientations.

## Research Log

### Existing screen and state seams

- **Context**: Identify the smallest UI changes that cover all requirements.
- **Sources Consulted**: `ContentView.swift`; `Views/ModeSelectionView.swift`, `SettingsView.swift`, `LocalLobbyView.swift`, `GameView.swift`, `ColorBarView.swift`, `ResultView.swift`, `ScoreView.swift`; `GameViewModel.swift`; `LocalPlay/LocalPlayCoordinator.swift`; `LocalGameSnapshotMapper.swift`; matching XCTest files.
- **Findings**: `ContentView` routes phases; `GameView` already limits three-device input to the local role; `ColorBarView` draws the existing ratio pie; result and score are separate screens. The coordinator currently permits host-only Mix/Redo/Finish and has no vote status. The view model has no mix-mode selection or live Auto Mix color.
- **Implications**: Retain view and phase ownership. Render Manual Mix with existing composition/result views. Render Auto Mix from an upstream computed display color. Show vote controls and progress only from local-play state; do not count votes inside views.

### iPhone orientation and device scope

- **Context**: The revised requirement is landscape iPhone and macOS, with iPad excluded.
- **Sources Consulted**: `ColorGameTesting2.xcodeproj/project.pbxproj`, `Config/LocalNetworkInfo.plist`, [Apple supported interface orientations](https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedinterfaceorientations), [Apple Xcode build settings](https://developer.apple.com/documentation/xcode/build-settings-reference).
- **Findings**: The iOS target has iPhone+iPad device family and no orientation declaration. Apple defines `UIInterfaceOrientationLandscapeLeft` and `UIInterfaceOrientationLandscapeRight` as supported-orientation values; Xcode also exposes generated Info.plist settings for iPhone orientation.
- **Implications**: Set the iOS target to iPhone-only in Debug and Release, add both landscape orientations to the target's Info.plist source, and verify the built app metadata on a simulator or device. No iPad windowing design is needed after the owner's scope change.

### Accessibility and constrained layout

- **Context**: The iPhone landscape play area must fit the request, bowl, action, and two color controls while preserving accessible content.
- **Sources Consulted**: Existing view accessibility modifiers, [Apple SwiftUI accessibility modifiers](https://developer.apple.com/documentation/swiftui/view-accessibility), [Apple `ViewThatFits`](https://developer.apple.com/documentation/swiftui/viewthatfits), layout sketch saved under `assets/`.
- **Findings**: Existing controls and ratio pie have partial accessible labels, while target and score swatches need explicit names. Platform layout tools can adapt to available space without a new package.
- **Implications**: Use a compact landscape layout driven by available size and shared visual roles; expose color names or values, vote state, and action state as text and accessibility metadata. Check the smallest supported iPhone and large text sizes before considering extra layout variants.

## Architecture Pattern Evaluation

| Option | Strengths | Risks / Limitations | Decision |
| --- | --- | --- | --- |
| Extend existing SwiftUI views with shared styles | Preserves phase and platform input patterns; smallest change surface | Needs careful layout sizing | Chosen |
| Separate iPhone screen tree | Maximum layout freedom | Duplicates round and action presentation | Rejected |
| New UI framework or package | Potential prebuilt controls | New dependency and integration cost without a requirement | Rejected |

## Design Decisions

### Decision: Views consume game and vote state

- **Context**: Multiple screens display the same shared round but do not own rule decisions.
- **Selected Approach**: Keep phase, mix mode, blend, action eligibility, and votes in existing game/local-play state; views render and forward typed actions.
- **Rationale**: This follows steering and prevents different screens or devices from disagreeing about a vote or result.
- **Trade-offs**: UI implementation waits for the adjacent specs' consumer-facing state contracts.
- **Follow-up**: Revalidate the UI design when those contracts are finalized.

### Decision: Reuse screen views with two small shared presentation helpers

- **Context**: All screens need consistent visual hierarchy; both gameplay and result need vote progress.
- **Selected Approach**: Add one shared style file for visual roles and one pure vote-status view; keep bowl mode selection inside `GameView` and reuse `ColorBarView` for Manual Mix.
- **Rationale**: This avoids a parallel app UI or generic component framework.
- **Trade-offs**: A future visual redesign still touches the existing views.
- **Follow-up**: Keep the helpers presentation-only.

## Risks and Mitigations

- **Upstream contract drift**: The adjacent specs have not yet added mix mode, live blend, or vote status. Treat those as implementation prerequisites and revalidate their final names and eligibility semantics before UI tasks.
- **Small landscape height**: Check request, bowl, controls, and text-size behavior on a small iPhone; allow secondary content to scroll without moving the primary color controls out of reach.
- **Target-color hint leakage**: Keep target swatch and accessibility value absent until allowed by the hint setting or score phase.
- **Validation environment**: `xcodebuild` currently points to Command Line Tools rather than Xcode; simulator/device orientation and touch checks remain pending until Xcode is selected.

## References

- [Apple supported interface orientations](https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedinterfaceorientations)
- [Apple Xcode build settings](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Apple SwiftUI accessibility modifiers](https://developer.apple.com/documentation/swiftui/view-accessibility)
- [Apple ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits)
