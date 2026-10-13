# Requirements: Endless Day Run

The developer needs continuous playtesting through Days instead of returning to setup after every target. The user approved the combined plan.md, including clarified failure rules and proposed timer/navigation details.

## Requirement 1: Configure the endless run

1. Settings shall provide seven editable templates with a positive client completion target and one Level 1–3 request slot per required success; each target defaults to three.
2. Default slot sequences shall be 1–1–1, 1–1–2, 1–2–2, 1–2–3, 2–2–3, 2–3–3, and 3–3–3.
3. Settings shall offer alternative Day and Client timer modes, with configurable defaults of 600 and 180 seconds respectively; Day mode is selected initially.
4. Settings shall provide a configurable passing score, default 70 percent, and a daily mistake limit, default three or unlimited.
5. Existing Mix Mode, reassignment duration, target hint, and level-aware custom-request entry shall remain available. The old one-target setup path shall be replaced by template-based run setup.
6. Configuration shall be editable only during settings with solo/host authority and remain unchanged during an active run.

## Requirement 2: Advance Days and customers

1. A new run shall start on Day 1 with zero completions and mistakes; targets shall be selected from the configured slot’s built-in/custom request level.
2. Days 1–7 shall use corresponding templates; Day 8 onward shall repeat templates 5–7, including their edited targets, while the Day number increases.
3. Manual Finish or Auto Apply shall grade the latest accepted mix using the existing score formula; a score at or above the configured threshold shall complete one customer exactly once.
4. A below-threshold grade shall add one mistake and offer Continue to a new target at the current level without advancing completion or slot.
5. Reaching the Day goal shall immediately pass the Day and stop its budget. Continue shall advance a customer or Day without returning to settings.
6. Starting the next Day shall reset daily mistakes/completions and start its budget. Existing RYB, assignment and mixing/vote rules shall remain intact.

## Requirement 3: Enforce time and mistake limits

1. Day time shall continue through unfinished Manual results, score feedback and pending votes; expiry before the Day goal shall cause Game Over.
2. Client time shall continue through Manual result and pending votes until grading; score feedback shall not consume client time.
3. A client timeout shall add one mistake, clear the bowl and automatically start a new customer at the current level with a fresh client budget unless the mistake limit ends the run.
4. Continue after a failed grade shall start a new target at the current level with a fresh client budget. Redo before grading shall neither add a mistake nor replenish a budget.
5. Reaching the configured daily mistake limit shall end the run in either timer mode; unlimited shall disable mistake-count failure.
6. Late grading/input/votes shall not override deadline expiry, and repeated callbacks or duplicate/stale inputs shall not count an attempt twice.
7. Connection/background pauses shall preserve the budget; recovery shall restore a full snapshot before clocks resume. Clients shall mirror host progress instead of computing deadlines or grading.

## Requirement 4: Present progression and preserve the group

1. Gameplay/result/score shall show current Day/stage, completed/required clients, daily mistakes, passing score and remaining budget; gameplay shall identify the request level.
2. Score shall offer Continue according to outcome; Game Over shall show its reason and offer Start Over using the same configuration from Day 1.
3. Gameplay’s host End Session action shall become Back to Settings/Lobby, abandoning run progress and stopping clocks while preserving session and seats; solo shall return to settings.
4. Host Back to Settings/Lobby shall work during a connection pause; starting again shall still require all three connected seats. Actual session-ending remains in the lobby.
5. Three-device Continue/Restart/Back shall be host actions; Mix/Finish/Apply/Redo shall retain two-matching-vote behavior and pending input rules.
6. A new wire version shall carry validated run/configuration/progress/timer/outcome/request-level state; older builds shall be rejected before snapshot application, and invalid snapshots shall not mutate clients partially.

## Request rotation update

Each difficulty level uses a shuffled queue containing its built-in and custom requests. Showing a client consumes that request, including clients that later fail or time out. A level repeats only after every request in its pool has appeared. Queues survive Day transitions and reconnects, and reset for a new run. Avoid consecutive repeats between cycles when alternatives exist. The host owns selection; clients receive the chosen request through snapshots.
