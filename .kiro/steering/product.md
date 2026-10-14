# Product Overview

ColorGameTesting is a local, three-player color-matching game built for playtesting. Players share one color mix and try to match a target request using assigned colors. The current app supports macOS and iOS. Its purpose as a playtesting project was confirmed by the project owner; the gameplay details below reflect the current app.

## Playtesting Purpose

Use the app to try the core game loop with people on one device and learn whether the controls, color assignments, reassignment pace, target hints, and result feedback make the game understandable and engaging. Favor changes that make a session easy to set up, run, observe, and repeat. Treat rules, timing, prompts, and presentation as things to evaluate and refine through playtesting, rather than fixed product requirements.

## Core Capabilities

- Configure an endless run with the fixed RYB palette and Manual or Auto Mix. Complete Day targets from three request levels; configure seven stages, then repeat stages 5–7. Day/client timers, passing score and daily mistakes are adjustable.
- Let three players add colors to one shared mix. Each player has two assigned color slots; macOS supports dedicated keyboard keys and iOS provides touch controls.
- Reassign player colors on a configurable timer while keeping the mix accumulated so far.
- In three-device play, Manual Mix requires all three votes; Manual result Redo/Finish and Auto Apply/Redo require two matching votes. Gameplay votes can be cancelled by tapping the selected action again. A pending voter cannot add colors until cancellation; other players can keep contributing. Manual result votes remain final.
- In Manual Mix, show ingredient proportions and a result before scoring. In Auto Mix, update the live color with each accepted contribution and apply it directly for scoring; both modes allow a redo.
- Add named custom target requests with hex colors and difficulty levels, retaining them locally for later runs.

## Primary Use Case

Three people play together on one device: choose a target, contribute colors during the round, inspect their result, and see how closely it matches. Successful requests continue within the run. Passing a Day advances to the next; failure offers Start Over or settings. Returning to the local lobby preserves connected player seats.

## Product Boundaries

- A round has one shared mix and three fixed players. Local sessions can use one device or three devices on the same Wi-Fi; the app does not maintain separate player scores.
- Built-in requests and custom requests supply target colors. Custom requests and built-in request deletion preferences persist between launches; round state and scores are transient.
- The score expresses color similarity using a perceptual color difference calculation. Treat it as game feedback, not a claim of physically accurate pigment mixing.
- Current sessions do not store playtest observations, analytics, or score history. Gather those through a separate process unless a future specification explicitly adds in-app collection.

_Updated 2026-10-07: clarified the project owner's playtesting purpose and the current boundary for session data._

---
_Keep this file focused on player experience and product intent, rather than individual screens or implementation details._
