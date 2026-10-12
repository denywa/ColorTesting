# Requirements Document

## Project Description (Input)

The project owner and future contributors need an accurate baseline for how playtesters add and reuse target requests. The settings screen already accepts a name and hex color, while the app validates, stores, and offers the resulting request for later rounds. This specification records that current lifecycle and its contract with round setup.

## Introduction

Players can add a named target color during setup and reuse it after restarting the app. This baseline defines entry, validation, local retention, and availability alongside built-in requests.

## Boundary Context

- **In scope:** Custom request entry, validation, local retention, loading, and exposure as a target choice.
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

1. While choosing a request, the ColorGameTesting app shall offer built-in and locally loaded custom requests in the target picker, along with a Random choice.
2. When a custom request is successfully added, the ColorGameTesting app shall select it as the current target choice.
3. When the player starts a round with a selected custom request, the ColorGameTesting app shall use that request's identity, name, and target color for the round.
4. When Random is selected at round start, the ColorGameTesting app shall choose a target from the available built-in and custom requests.
