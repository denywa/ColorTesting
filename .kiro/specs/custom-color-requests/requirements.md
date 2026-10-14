# Requirements Document

## Project Description (Input)

The project owner and future contributors need an accurate baseline for how playtesters add and reuse target requests. The settings screen already accepts a name and hex color, while the app validates, stores, and offers the resulting request for later rounds. This specification covers that lifecycle and its extension to three difficulty pools for playtesting.

## Introduction

Players can add a named target color during setup and reuse it after restarting the app. The app groups built-in and custom requests into three temporary difficulty levels, filters setup choices by level, and retains new requests with their assigned level.

## Boundary Context

- **In scope:** Custom request entry, validation, local retention, loading, difficulty classification, and exposure as a level-filtered target choice.
- **Out of scope:** Request deletion or editing, remote catalog synchronization, player input, mixing, scoring, and phase transitions beyond the setup contract.
- **Adjacent expectations:** Round setup consumes the available request list and chosen target. In three-device play, the host may use its local custom target for a shared round; the network mode owns transmission of that round target and does not copy the host's saved catalog to guests.

## Requirements

### Requirement 1: Enter a custom request

**Objective:** As a player setting up a round, I want to enter a named target color so that the group can play with a color of its choosing.

#### Acceptance Criteria

1. While the settings screen permits local setup, the ColorGameTesting app shall offer an Add color request action beside the target choice.
2. When the player opens the Add color request form, the ColorGameTesting app shall provide a request-text field, a hex-color field, and Cancel and Add actions.
3. When the hex field contains a valid color, the ColorGameTesting app shall display a color preview and its normalized hex value.
4. While the request text contains only whitespace or the hex value is invalid, the ColorGameTesting app shall disable the form's Add action.

### Requirement 2: Validate and create a request

**Objective:** As a player, I want an accepted request to have a usable name and exact target color so that it appears consistently in later rounds.

#### Acceptance Criteria

1. When a request is added, the ColorGameTesting app shall trim surrounding whitespace from its name and reject a name that becomes empty.
2. When a hex color is entered, the ColorGameTesting app shall accept exactly six hexadecimal digits with an optional leading `#`, ignoring surrounding whitespace and letter case.
3. If the submitted color contains any other format or character, the ColorGameTesting app shall reject the request without adding it.
4. If request creation is attempted outside settings or without local authority to change game rules, the ColorGameTesting app shall leave the request list unchanged.

### Requirement 3: Retain valid custom requests locally

**Objective:** As a returning player, I want valid custom requests to remain available on this device so that I can reuse them in another session.

#### Acceptance Criteria

1. When a valid request is accepted, the ColorGameTesting app shall retain its name, target color, and identity locally before making it available in the current session.
2. When the app's game model is created again on the same device, the ColorGameTesting app shall load previously retained valid custom requests with their identities, names, and target colors preserved.
3. If retained request data cannot be decoded, the ColorGameTesting app shall start with no loaded custom requests while retaining its built-in requests.
4. If a decoded retained request has a blank name or invalid hex color, the ColorGameTesting app shall omit that request from the available custom choices.

### Requirement 4: Offer custom requests for a round

**Objective:** As a player choosing a target, I want saved custom requests beside built-in choices so that I can choose one or let the app pick randomly.

#### Acceptance Criteria

1. While choosing a request, the ColorGameTesting app shall offer built-in and locally loaded custom requests from the selected difficulty level in the target picker, along with a Random choice.
2. When a custom request is successfully added, the ColorGameTesting app shall select it as the current target choice.
3. When the player starts a round with a selected custom request, the ColorGameTesting app shall use that request's identity, name, and target color for the round.
4. When Random is selected at round start, the ColorGameTesting app shall choose a target only from the selected difficulty level’s available built-in and custom requests.

### Requirement 5: Select and manage three difficulty pools

**Objective:** As the playtest developer, I want to choose a request difficulty and assign new requests to it so that I can test levels while preparing new copywriting.

#### Acceptance Criteria

1. The ColorGameTesting app shall provide Level 1 — Easy, Level 2 — Medium, and Level 3 — Hard, preserving all existing built-in request IDs, prompt text and target colors. The initial groups are Red blood/Juicy orange; Sky blue/Lavender/Honey blonde; Glossy mocha brown/Milk tea, respectively.
2. When a new app session opens settings, the ColorGameTesting app shall select Level 1 and offer a level selector to the player authorized to configure the round.
3. When the selected level changes, the ColorGameTesting app shall filter request choices to that level and clear a previously selected request belonging to another level.
4. When the Add Color Request form opens, the ColorGameTesting app shall initialize its level selector to the settings level and allow the developer to choose any of the three levels.
5. When a custom request is saved, the ColorGameTesting app shall retain its level along with its identity, text and target, switch settings to that level, and select the new request; reloading the app shall preserve the saved level.
6. When previously saved custom data contains no level, the ColorGameTesting app shall load those requests into Level 1 while preserving their identity, text and target color.
7. When New Round returns to settings, the ColorGameTesting app shall retain the selected level for repeated testing while preserving the existing Manual Mix reset behavior.
8. While three-device play is active, the ColorGameTesting app shall restrict request-level selection and catalog additions to the host; the selected target shall still synchronize through the existing network flow without writing to client catalogs.
9. The ColorGameTesting app shall preserve the existing mixing, assignments, voting, scoring, and request-validation rules when selecting a level.

## Request deletion update

Solo players and the host may delete built-in or custom requests from the settings library. Custom entries are removed from saved records; built-in deletions are stored as stable ID exclusions on that device. Clear deleted selections and cached selection queues. Deletion is settings-only and does not change active rounds or guest libraries. Empty configured levels disable Start Run and show guidance to add requests or edit the schedule.
## Request editing update — 2026-10-14

In the settings lobby, the host or solo player can edit the text, six-digit hex target color, and difficulty of any available built-in or custom request. Editing preserves the request ID, validates non-empty text and a valid hex color, and persists locally. Built-in edits override their originals without duplicating them in the pool. Deleting an edited built-in removes its override and keeps the original hidden after relaunch. Editing is rejected during active gameplay and for guest devices. The existing Add form is reused with prefilled values, Save, and Cancel; Cancel leaves stored requests unchanged.
