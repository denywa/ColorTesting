# Project Structure

## Organization Philosophy

The repository uses a small, responsibility-based layout inside one Xcode project. Shared app code lives in `ColorGameTesting/`, SwiftUI screens and reusable display views live in `ColorGameTesting/Views/`, and the parallel `ColorGameTestingTests/` target mirrors production behaviors. The app and test source folders are filesystem-synchronized Xcode groups.

## Responsibility Boundaries

### App flow and state

`ColorGameTestingApp` launches `ContentView`; `ContentView` owns the view model and routes `GamePhase` to the appropriate screen. Put round state and transitions in `GameState`, `GameModels`, and `GameViewModel` rather than distributing them across screen files.

### Views

Put screen and reusable SwiftUI view types in `Views/`. Views receive the shared view model or value inputs and call its actions. Keep a helper that only serves one screen private to that screen file; use `#Preview` for view previews where useful.

### Domain helpers and data

Keep model definitions, palette/request data, color math, scoring, key routing, and request persistence in focused Swift files at the app-source root. For example, `ColorMixer` handles blending while `ScoreCalculator` handles match scoring. A new helper should have one clear domain responsibility and should not depend on SwiftUI rendering.

### Tests and assets

Put XCTest files in `ColorGameTestingTests/`, naming them after the production behavior or type they exercise, such as `ColorMixerTests`. Put app colors and icons in `Assets.xcassets`.

## Naming and Imports

- Use PascalCase for Swift files and types; keep role suffixes such as `View`, `ViewModel`, and `Tests`.
- Use descriptive lowerCamelCase names for methods and properties, following the existing Swift code.
- Import system frameworks at the file level (`SwiftUI`, `Foundation`, `Observation`), and conditionally import platform frameworks such as `AppKit` when applicable. App types share one module, so they do not require local module imports.
- Use `@testable import ColorGameTesting` in test files.

---
_Describe where a kind of work belongs. New files following these patterns should not require a steering update._
