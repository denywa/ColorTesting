# Design: Endless Day Run

## 3. Design

### Responsibility boundary

A new endless-run domain owns seven-template configuration, Day/customer progress, deadline budget, daily mistakes and outcome classification. GameViewModel owns integration with its existing request/round lifecycle. LocalPlayCoordinator owns authoritative action acceptance, votes and synchronization. Views configure and render those states, without counting mistakes or deciding failure themselves.

No change to ColorMixer, ScoreCalculator or CustomRequestStore is required. Existing request difficulty supplies the target pool.

### State and interfaces

- `DayTemplate`: ordered request difficulty slots; its completion target is the slot count, avoiding conflicting goal/list fields.
- `EndlessRunConfiguration`: seven templates, timer mode, both duration values, passing score and optional mistake limit. Validate positive targets/durations, exactly seven templates, supported levels and a 0–100 threshold.
- `EndlessRunState`: run identity, current Day/template, completed customers, current target/attempt identity, daily mistakes, budget, last attempt outcome, and active/day-complete/game-over status.
- A deadline/budget helper uses an injectable clock for deterministic tests. The host derives remaining seconds from a deadline, rather than assuming every Timer callback represents exactly one elapsed second. Pausing captures the remaining budget; resuming creates a new deadline from it.
- View-model actions start a run, grade a request through the current actions, advance from feedback, restart, and return to settings. Configuration mutation is settings-only and respects existing authority.
- Continue to a new customer creates a new request identity/round ID and empty bowl. Each new client selects another target at the configured current level when available, uses a fresh round ID, resets assigned colors and reassignment timing, and clears the bowl. Mistakes are retained within the Day.
- Publish each score, timeout, transition and budget update atomically. Repeated timer callbacks or duplicated grading inputs cannot count one attempt twice.

### Local-session integration

Upgrade the wire protocol for the new run/configuration, timer, progress and Game Over fields. Preserve the Hello/Reject compatibility gate so older builds are rejected before applying snapshots. Transfer the active request level when it becomes displayed during an endless run.

Snapshots include validated configuration, progress, status, timers, outcome and the existing round/voting state. Extend mapper validation for Game Over and the new invariants; apply only fully valid snapshots. Clear/rotate ballots before domain mutations publish a timeout, new customer, return or terminal state.

Host Continue/Restart requires the normal connected/unpaused action gate. Host Back to Settings/Lobby is available during a connection pause so the group can abandon a run without losing seat identities; the settings snapshot must clear gameplay pause/progress and still prevent starting until all three seats are connected.

### Screens

- Settings: run timing, threshold, mistakes and a seven-template editor; retain Mix Mode, reassignment/hint settings and level-aware Add Request. The old one-target picker is replaced as the gameplay setup path; targets are chosen by template slots.
- Gameplay: Day number, template, completed/required customers, mistakes/unlimited, current request level and remaining budget; preserve the landscape bowl/inputs/actions.
- Result: retain Manual result and voting, display the applicable budget.
- Score: passed/failed request, threshold and score; Continue advances within the run.
- Game Over: reason, Day reached, progress/mistakes and Start Over/Back to Settings/Lobby.
- Routing/navigation: preserve solo/local choice and local seats while returning to setup.

### Concrete files

| Boundary | Files |
| --- | --- |
| Run models and deterministic deadline/progression | New ColorGameTesting/EndlessRun.swift |
| Domain integration and Game Over phase | GameViewModel.swift, GameState.swift, GameModels.swift |
| Protocol, host actions, mapper and pause/recovery | LocalPlay/LocalPlayModels.swift, LocalMessageCodec.swift, LocalPlayCoordinator.swift, LocalGameSnapshotMapper.swift |
| Setup and run UI | Views/SettingsView.swift, GameView.swift, ResultView.swift, ScoreView.swift; new GameOverView.swift and compact run-status view; ContentView.swift |
| Focused validation | New endless-run/progression tests and relevant existing flow, coordinator, mapper, codec and screen tests |


## Implemented Timing Details

The default deadline clock uses system uptime represented as a private Date value; no calendar timestamp is sent to clients. RunTimer uses common run-loop modes so menus/scroll tracking do not suspend it. A clock read is injectable in tests. Remaining-time updates during a domain action are folded into its final snapshot to avoid publishing a cleared majority ballot in the old phase.

Validation bounds: seven templates, 1–100 clients per template, durations 1–86400 seconds, passing score 0–100, and a 1–100 or unlimited mistake cap. UI duration steppers use minutes. These bounds protect incoming configuration/state before rendering and allocation.

Active configuration is immutable. Color math and custom-request persistence are unchanged. Snapshot protocol is version 3; target difficulty and complete run state are synchronized.

## Validation

EndlessRunTests and EndlessNetworkTests cover thresholds, duplicate grading, looping/edited goals, next-client/Redo clocks, deadline boundaries, pause/recovery, majority outcomes, invalid snapshots, stale votes, session-preserving navigation, and old-version rejection. Existing focused input/coordinator/flow/codec/mapper/setup/navigation checks passed. Both final platform builds passed. User device review is not represented as automated evidence.

## Request rotation update

Each difficulty level uses a shuffled queue containing its built-in and custom requests. Showing a client consumes that request, including clients that later fail or time out. A level repeats only after every request in its pool has appeared. Queues survive Day transitions and reconnects, and reset for a new run. Avoid consecutive repeats between cycles when alternatives exist. The host owns selection; clients receive the chosen request through snapshots.
