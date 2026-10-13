# Implementation Plan: Endless Day Run

Approved as the combined plan.md by the user. Efficient workflow: grouped main-context implementation, focused checks, no separate reviewers and no per-task commits.

- [x] 1. Implement run configuration, progression and deadline budgets
  - Seven editable templates, looping 5–7, level-specific targets, threshold, daily goals/mistakes and pause-aware deadline clock are implemented in EndlessRun.swift and GameViewModel.
  - Done: deterministic threshold, deadline, next-client, unlimited and edited-template checks pass.
  - _Boundary: EndlessRun and GameViewModel explicit run/round integration_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
- [x] 2. Integrate host-owned local snapshots, actions and recovery
  - Protocol v3, target level/run fields, atomic mapper validation, new host actions, stale-attempt/ballot rejection and restored budgets are integrated through the existing coordinator/transport interfaces.
  - Done: fake-peer progression, third-timeout Game Over, majority publication, pause/recovery and session-preserving return pass.
  - _Boundary: LocalPlayModels, LocalPlayCoordinator and LocalGameSnapshotMapper integration_
  - _Depends: 1_
  - _Requirements: 3.6, 3.7, 4.3, 4.4, 4.5, 4.6_
- [x] 3. Integrate settings, progress, feedback and Game Over
  - Settings replaces single-request setup with run settings/schedule editing and keeps the custom request library. Gameplay/result/score render run status; Continue and Start Over use the domain; Back to Settings/Lobby preserves players.
  - Done: focused setup/navigation checks, compact gameplay captures and macOS/iOS builds pass. The rebuilt artifact is available for manual review.
  - _Boundary: ContentView and run-aware SwiftUI screens_
  - _Depends: 1, 2_
  - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.6, 4.1, 4.2, 4.3, 4.4, 4.5_

## Verification Notes

Focused Xcode runs: /private/tmp/endless-focused.log, /private/tmp/endless-integration.log, /private/tmp/endless-final-check.log. Final run reported 15/15: 14 domain/network tests plus one temporary visual-capture check. The capture helper was removed afterward; images remain under /private/tmp/endless-*.png. Older result bundles were pruned by Xcode; their successful console logs remain. Final builds: /private/tmp/endless-mac-final.log and /private/tmp/endless-ios-final.log.

The full suite and physical-device/touch/VoiceOver checks were not repeated. Software completion is not a claim of real-device validation or independent review.
