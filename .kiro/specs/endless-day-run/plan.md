# Endless Day Run — Combined Requirements, Design and Implementation Plan

Status: the user approved requirements, design and implementation plan together. Software implementation and focused checks are complete; physical-device review remains manual.

## 1. Requirements

### Configuration

- Replace the repeated single-request/setup loop with a run configured once and continuing through numbered Days until failure or returning to settings.
- Keep seven editable Day templates. Each template has a positive completion target and one request-level slot per required successful customer. Target defaults to three; changing it adds/removes configurable slots.
- Request levels remain 1–3. Preserve existing request text/colors, level-aware custom catalogs, RYB mixing, assignments and Manual/Auto choice.
- Default templates: 1 = 1–1–1; 2 = 1–1–2; 3 = 1–2–2; 4 = 1–2–3; 5 = 2–2–3; 6 = 2–3–3; 7 = 3–3–3.
- Days 1–7 use their matching template. Day 8 onward repeats templates 5, 6 and 7; the visible Day number continues increasing. All properties of the reused template, including its completion target, repeat.
- Select one timer mode: Day Timer (default ten minutes per Day) or Client Timer (default three minutes per customer attempt). Durations are configurable before starting. Day Timer is initially selected.
- Configure one match-score threshold for the run, default 70 percent. A finite score at or above the threshold completes the current customer.
- Configure maximum mistakes per Day, default three, or unlimited. Mistakes reset only at a new Day. The third mistake at the default limit ends the run.
- In local play, the host configures and starts the run. Clients receive progress and continue using their own two colors.

### Progress, mistakes and failure

- Start at Day 1 with zero completed customers and zero mistakes. Pick a target randomly from the level of the current template slot, including saved custom requests in that level.
- Manual Mix grades only at Finish; Auto Mix grades at Apply. Preserve the score formula. One accepted grading action updates completion or mistakes exactly once.
- Below-threshold scoring adds one mistake and offers Continue to the new target at the current level; failed attempts do not advance the level slot or count toward the Day target.
- Client timeout adds one mistake. Client timeout behavior: if the limit was not reached, clear the bowl and automatically start a new customer at the current level with a fresh client timer. Select a different target when the current level has alternatives, and reset assignments.
- Day timeout ends the run if the completion target is not yet reached, irrespective of mistake count.
- Completing the Day target passes the Day immediately and stops its budget. Continue starts the next Day; no return to settings.
- The reached mistake limit ends the run in either timer mode, even if time remains. Unlimited mistakes disables this failure condition; Client Timer plus unlimited mistakes permits unlimited unsuccessful clients.
- Provide Start Over (Day 1, same configuration) and Back to Settings/Lobby after Game Over.
- In gameplay, replace the host’s End Session action with Back to Settings/Lobby. Returning abandons run progress, stops clocks and preserves the connected session and seats. Solo returns to settings. The lobby retains the actual session-ending action.

## 2. Proposed Timing and Interaction Details

- Day budget continues through Manual result, score feedback and pending votes while the Day is unfinished. It stops on Day completion, failure, return to settings or network pause.
- Client budget continues through Manual result and pending votes until a score is produced. Score feedback has no ticking client budget. Continue after a failed grade starts a new target at the current level with a fresh client budget; after success it starts the next customer’s budget.
- Redo before scoring clears the bowl but neither counts as a mistake nor replenishes the Day/client budget. The existing color-reassignment countdown remains separate and retains its current result/score pause behavior.
- In solo, Continue, Start Over and Back to Settings are direct. In three-device play, the host advances/restarts/returns the group; existing Mix/Finish/Apply/Redo decisions retain the two-matching-vote rule.
- On score feedback, show Next Client after either a success or a nonterminal unsuccessful grade. The completed-Day state clearly identifies the next Day. Client timeouts display a mistake/new-client notice in gameplay; they do not fabricate a score.
- A grading/input/vote action received at or after its host deadline cannot override timeout. Expiry is processed before accepting a late action. Old customer/attempt and ballot IDs cannot affect the next customer.
- Pause run budgets when a local session pauses or the host backgrounds. Resume only after the restored full snapshot is delivered. Clients mirror the host and do not run their own progression/deadline logic.

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

## 4. Grouped Implementation Plan

1. Implement run configuration, repeating templates, deadline budgets and deterministic progression/mistake rules, plus focused domain tests.
2. Integrate the new lifecycle and host-owned local snapshots, action/ballot rotation and recovery. Update the affected contract fixtures and focused integration checks.
3. Integrate settings, progress, feedback, Game Over and Back to Settings/Lobby; build macOS and iOS and launch the rebuilt artifact for manual review.

Use the user’s efficient workflow: grouped work, no separate review agent, no per-task commit or repeated full-suite runs. Run focused checks that cover concrete changed risks and one final build per platform; report manual checks honestly.

## 5. Validation Cases

- Days 1–7 follow all defaults; Days 8–13 reuse 5/6/7 twice, including edited goals and difficulty slots.
- Custom goal sizes and target selection use only the configured level; failed clients do not advance completion progress.
- Score exactly 70 passes at the default; below 70 adds one mistake once; the third mistake fails; unlimited does not fail on count.
- Day expiry before completion fails; completion before expiry freezes the Day budget. Client expiry counts once and either starts another client or fails at the limit.
- Each new client receives the approved fresh budget; Redo never replenishes a deadline. Delayed ticks/actions, exact-deadline scoring, pause/resume and result/feedback timing obey the selected mode.
- Majority grading uses the newest accepted bowl; stale ballots and messages cannot affect a reset customer. Clients cannot independently advance, grade or change run settings.
- Return to Settings/Lobby preserves session/seats and stops all run/input clocks. Start Over resets Day/progress/mistakes and retains configuration.
- New protocol rejects older builds; invalid run/configuration/status snapshots are rejected atomically. Reconnect restores all progress and budget before resuming.
- Both platform builds and relevant focused checks pass. Real-device timing, touch ergonomics and three-device end-to-end behavior are left for the user’s manual review.

## Request rotation update

Each difficulty level uses a shuffled queue containing its built-in and custom requests. Showing a client consumes that request, including clients that later fail or time out. A level repeats only after every request in its pool has appeared. Queues survive Day transitions and reconnects, and reset for a new run. Avoid consecutive repeats between cycles when alternatives exist. The host owns selection; clients receive the chosen request through snapshots.
