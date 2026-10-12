# Technology Stack

## Architecture

This is a native SwiftUI app with shared source for macOS and iOS targets. `ContentView` owns a `GameViewModel` and selects a screen from the current `GamePhase`. The main-actor, observable view model coordinates state transitions, timing, input, and persistence. Value types and focused helpers implement game rules and color calculations outside the views.

## Core Technologies

- **Language**: Swift, with the Xcode project set to Swift 5 language mode.
- **UI and observation**: SwiftUI and the Observation framework (`@Observable`).
- **Platforms**: macOS and iOS app targets in `ColorGameTesting2.xcodeproj`; the project sets macOS 27.0 and iOS 17.0 deployment targets.
- **System APIs**: Foundation for state, timers, and local `UserDefaults` storage; AppKit for the macOS keyboard monitor.
- **Dependencies**: No third-party packages are declared in the Xcode project.

## Development Standards

### State and UI

Keep phase transitions and round mutations in `GameViewModel`. Views render state and forward player actions. Use `#if os(macOS)` and `#if os(iOS)` for platform-specific input or presentation where needed. Keep timer and keyboard-monitor lifecycle tied to the playing phase.

### Color and persistence

Represent color components with `SIMD3<Double>` or `SIMD4<Double>` as appropriate. Keep palette data, color blending, color-space conversion, and scoring in their focused helpers. Mix in the selected model's component space; score the displayed result against the target through Lab and Delta E 2000. Persist custom requests as validated, Codable data in `UserDefaults`; allow injection of a defaults instance for tests.

### Testing

Use XCTest in `ColorGameTestingTests`, with `@testable import ColorGameTesting`. Test domain calculations, state transitions, persistence, and SwiftUI rendering where behavior warrants it. Mark tests that use main-actor UI or view-model APIs with `@MainActor`. The shared macOS scheme includes the test target; the iOS scheme does not currently define a test action.

### Playtesting iteration

Keep adjustable session conditions, such as the reassignment duration and target hint, easy to change from settings. Keep the path from setup through result and score to another round short, and make player actions and outcomes visible enough to discuss during a session. When changing the rules or scoring, protect the intended behavior with focused tests so playtest feedback can be interpreted against a stable implementation. Do not assume telemetry or saved round history exists; the current app only persists custom requests.

## Development Environment

Use Xcode and its command-line tools. The shared schemes are `ColorGameTesting` for macOS and `ColorGameTestingiOS` for iOS. A macOS test command is:

```bash
xcodebuild -project ColorGameTesting2.xcodeproj -scheme ColorGameTesting -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

The command follows the project and scheme configuration; it is not a recorded test result.

---
_Document technical decisions that should guide new work, not every framework import or build setting._

_Updated 2026-10-07: added development priorities for the project's playtesting purpose._
