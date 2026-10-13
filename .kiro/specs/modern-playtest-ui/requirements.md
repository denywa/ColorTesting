# Requirements Document

## Project Description (Input)

Playtesters need to understand their assigned colors, shared bowl, target request, mix mode, and group decisions at a glance. The current SwiftUI interface is vertically stacked on iOS and lacks the requested landscape layout for three-device play; its screens also need a clearer, more consistent visual design. Redesign all screens, starting with gameplay: show the request at the upper left, bowl in the center, and the local player's two color controls at the lower left and right; present Manual Mix, Auto Mix, and three-device vote progress clearly while preserving the game rules owned by adjacent specs.

## Introduction

This specification defines the user-facing presentation for Playtesting Part II on iPhone and macOS across mode selection, setup, the local lobby, gameplay, result, and score. The attached layout sketch guides placement on the iPhone three-device gameplay screen; it does not prescribe final colors or styling.

## Boundary Context

- **In scope**: Screen hierarchy and visual consistency, iPhone landscape layouts, presentation of the local player's controls and shared bowl, Manual Mix and Auto Mix feedback, vote and connection status, and accessible interaction on iPhone and macOS.
- **Out of scope**: iPad support, color assignment and blending rules, match-score calculation, mix-mode phase rules, vote counting, network synchronization, and request storage.
- **Adjacent expectations**: The round-flow and local-play features supply the current mode, phase, valid actions, mix, assignments, and vote state. This interface presents those states and lets players request actions; it does not decide their outcomes.

## Requirements

### Requirement 1: Consistent screen hierarchy

**Objective:** As a playtester, I want each screen to make my next action and the current game state clear so that I can play without deciphering the layout.

#### Acceptance Criteria

1. When mode selection, setup, lobby, gameplay, result, or score is displayed, the ColorGameTesting app shall provide a visible screen heading.
2. When a screen has a primary action, the ColorGameTesting app shall distinguish it visually from secondary controls.
3. The ColorGameTesting app shall use the same visual treatment for headings, primary actions, secondary actions, status labels, and player roles across these screens.
4. When the game changes phase, the ColorGameTesting app shall update the visible heading and actions to match the new phase.
5. If an action is unavailable because its game precondition is unmet, the ColorGameTesting app shall show it as unavailable rather than allowing a misleading interaction.
6. While the score screen is displayed, the ColorGameTesting app shall present the available New Round action.

### Requirement 2: Clear setup and local-session status

**Objective:** As a player, I want to see the selected play and mix modes and the status of my group so that I know how the round will work.

#### Acceptance Criteria

1. While mode selection is displayed, the ColorGameTesting app shall visibly distinguish one-device play from three-device play.
2. While setup is displayed, the ColorGameTesting app shall visibly distinguish the selected Manual Mix or Auto Mix option.
3. While setup is displayed, the ColorGameTesting app shall show the selected request, reassignment duration, and target-hint setting before the round starts.
4. While the custom-request form is displayed on iPhone, the ColorGameTesting app shall keep its entry fields, validation feedback, and Add and Cancel actions readable in landscape.
5. While the local lobby is displayed, the ColorGameTesting app shall show the local player's role and the connection status of all three player seats.
6. If a local session is waiting for a player or has a connection error, the ColorGameTesting app shall display the reason and the available next action.

### Requirement 3: Landscape iPhone gameplay layout

**Objective:** As a player using my own iPhone, I want my colors and the shared objective placed around the bowl so that I can act quickly in landscape.

#### Acceptance Criteria

1. The ColorGameTesting app shall support iPhone and macOS while excluding iPad from the iOS device target.
2. While the app is running on iPhone, the ColorGameTesting app shall present mode selection, setup and its forms, lobby, gameplay, result, and score in landscape orientation.
3. While three-device gameplay is displayed on iPhone, the ColorGameTesting app shall place the target request at the upper left and the shared bowl centrally.
4. While three-device gameplay is displayed on iPhone, the ColorGameTesting app shall place only the local player's two assigned color controls at the lower left and lower right of the play area.
5. While three-device gameplay is displayed on iPhone, the ColorGameTesting app shall keep the player's role and reassignment countdown visible without obscuring the request, bowl, or color controls.
6. If the supported iPhone landscape display size changes, the ColorGameTesting app shall keep the request, bowl, primary actions, and color controls visible and free of overlap.
7. While one-device gameplay is displayed on iPhone, the ColorGameTesting app shall keep controls for all three players available and identify which player owns each pair.

### Requirement 4: Manual Mix presentation

**Objective:** As a player using Manual Mix, I want to inspect the accumulated ingredients before committing the result so that the existing mix flow remains understandable.

#### Acceptance Criteria

1. While Manual Mix gameplay is displayed, the ColorGameTesting app shall show the accumulated ingredient composition in the bowl area.
2. While Manual Mix gameplay is displayed on iPhone, the ColorGameTesting app shall place the Mix action below the bowl.
3. When a valid Manual Mix action completes, the ColorGameTesting app shall show the resulting color and each ingredient's proportion in the result view.
4. While the Manual Mix result is displayed, the ColorGameTesting app shall show Redo and Finish actions.
5. When Finish completes, the ColorGameTesting app shall show the resulting color beside the target color with the match score.

### Requirement 5: Auto Mix presentation

**Objective:** As a player using Auto Mix, I want each contribution reflected in the bowl without an extra Mix step so that I can decide when to apply or redo the color.

#### Acceptance Criteria

1. When an accepted color contribution changes an Auto Mix round, the ColorGameTesting app shall update the bowl to the current blended color without requiring a Mix action.
2. While Auto Mix gameplay is displayed, the ColorGameTesting app shall omit the ingredient-ratio pie chart and Mix action.
3. While Auto Mix gameplay is displayed, the ColorGameTesting app shall show Apply and Redo on the same gameplay screen as the bowl.
4. When a valid Auto Mix Apply action completes, the ColorGameTesting app shall show the resulting color beside the target color with the match score.
5. When a valid Auto Mix Redo action completes, the ColorGameTesting app shall show the cleared bowl on the gameplay screen.

### Requirement 6: Three-device vote and interruption feedback

**Objective:** As a player on my own device, I want to see whether my group has agreed on an action so that I know why play is waiting.

#### Acceptance Criteria

1. While an action requiring agreement is available in three-device play, the ColorGameTesting app shall offer each player a control to vote for that action on their device.
2. When a player votes for Mix, Apply/Finish, or Redo in three-device play, the ColorGameTesting app shall indicate that player's selected action while agreement is pending.
3. While a shared vote remains pending, the ColorGameTesting app shall show the current vote status of each player role on every connected device.
4. While an action is awaiting two matching votes, the ColorGameTesting app shall show that it is pending rather than completed.
5. If the local session pauses because a player disconnects, the ColorGameTesting app shall identify the disconnected player.
6. While a local session is paused, the ColorGameTesting app shall show play and voting controls as unavailable until the session resumes.
7. While one-device play is active, the ColorGameTesting app shall present Mix, Apply/Finish, and Redo as direct actions without vote status.
8. When two matching votes complete a three-device action, the ColorGameTesting app shall show its resulting state without waiting for the third player's vote.

### Requirement 7: Accessible color and action information

**Objective:** As a player using accessibility settings or keyboard controls, I want the same game information and actions available without relying only on color or position.

#### Acceptance Criteria

1. When an assigned color control is displayed, the ColorGameTesting app shall identify its player and color in visible text and an accessible name.
2. When the bowl is displayed, the ColorGameTesting app shall provide an accessible description of whether it is empty or what color it currently shows.
3. When a target hint, result color, or target comparison is displayed, the ColorGameTesting app shall provide an accessible name that identifies the swatch and its color.
4. When mix mode, countdown, connection status, or vote status changes, the ColorGameTesting app shall expose the updated state to assistive technology.
5. While macOS gameplay is displayed, the ColorGameTesting app shall preserve the visible keyboard assignments for each player's two colors.
6. If a player increases the supported text size, the ColorGameTesting app shall keep primary actions and game status readable and operable without overlap.
7. While the target-color hint is enabled, the ColorGameTesting app shall show the target-color swatch beside the request text.
8. While the target-color hint is disabled, the ColorGameTesting app shall omit the target color from both the visible request presentation and its accessible description until the score comparison.

## Approved iPhone compact layout refinement

The host settings room uses one vertical scroll owner for embedded lobby and setup content. Connected seats appear in one compact row; the request library is collapsed initially. Landscape gameplay and Manual result use fixed, non-scrolling layouts. Gameplay places the request at the upper left, run timer above the central bowl, Day/client/mistake progress at the upper right, color controls at the lower corners, and mix actions and compact final-vote indicators below the bowl. Solo retains all six color controls. iPhone gameplay removes visible role and color reassignment countdown labels; iPhone run status removes the passing threshold. These changes affect presentation only: countdowns, grading, authority, votes and disconnect pauses retain their behavior.

## Request emphasis and outcome feedback

The landscape iPhone request card uses a warm contrasting fill and border and aligns with the Day/client card. Remaining lives appear above the request as filled/empty hearts, replacing mistake-count text; unlimited lives and large configured limits use a heart with infinity or a numeric count. Scores prioritize green PASS/checkmark or red MISS/cross with a secondary percentage. Client-timer mode uses a person icon. Both timer modes show a centered, dismissible request overlay when a new client starts; timeout notices identify the lost life when limits apply. The overlay dims the background and blocks underlying touch controls while the timer continues. Its automatic three-second task cancels when the request or view changes.

## Shared header and request overlay refinement

On iPhone, gameplay, Manual breakdown, and score use one shared top header: lives on the left, timer centered, Day/client progress beside Lobby on the right. Guests retain Leave. Remove the additional outer navigation row on these screens. The large request overlay has an accessible X button and scrollable full text; new-client notices appear in both timer modes and close automatically after three seconds. Truncated gameplay requests use a bold See more control to reopen the overlay until explicitly dismissed. A parent-owned last-noticed round ID prevents Redo from announcing the same client again. Returning to settings/lobby preserves existing authority and session behavior.

## Manual breakdown continuity

The iPhone Manual breakdown retains the same request card position and full-request overlay as gameplay. Show the mixed color beneath the request, with the compact ingredient list on the right. Ingredients show only color names and unit counts, including accessibility labels. Voting status sits immediately above Redo/Finish in the right column. Preserve the shared top header and non-scrolling layout.

## Simplified mix summary

Replace the ingredient table with the reference layout: Your Mix above a broad swatch, with five vertically ordered palette dots and numeric unit counts alongside it, including zero counts. Keep spoken color names for accessibility. On iPhone, place this summary beside the unchanged request card; keep voting directly above Redo/Finish, without scrolling.

## Bowl continuity and longer request previews

Request cards show two preview lines in compact cards and three in taller cards before See more. Gameplay and breakdown reuse the same circular bowl component. In iPhone three-device play, breakdown uses the same center-column bowl size and position as gameplay, with a noninteractive YOUR MIX label in the former Mix-action position. Keep palette dots/counts and voting above compact Redo/Finish controls in the right column.

## Mac parity with the approved iPhone layout

Mac and iPhone now share adaptive gameplay, breakdown and score layouts, request cards/notices, lives/timer/progress headers, compact votes, and one lobby/settings scroll owner. Mac retains key labels and six solo controls, uses larger bowls/comparison swatches where space permits, and has a 680×480 minimum content size with a 1000×600 default window. Keep the solo bowl position consistent across gameplay and result. Preserve Lobby/Leave navigation even when active-screen data is missing. The accepted iPhone sizes and layouts remain unchanged for normal play.
