# Design Document: Custom Color Requests

## Overview

Extend the existing request catalog with three difficulty groups for playtesting. Keep all current built-in text, target colors and IDs. The settings picker and Add Color Request form consume the same typed level metadata, while existing storage and round-control paths continue to own their current responsibilities.

### Goals

- Filter explicit and Random target choices by the selected level.
- Save and reload a custom request’s level without losing older saved records.
- Support repeated testing of one level in solo and host-controlled sessions.

### Non-Goals

New copywriting, new colors, request editing/deletion, automatic difficulty estimation, client catalog synchronization, changes to mixing/scoring/voting, or new dependencies.

## Boundary Commitments

### This Spec Owns

Request-level metadata, initial catalog classification, local persistence, filtered setup choices and custom entry. GameViewModel integrates the chosen catalog with the existing round-start consumer.

### Out of Boundary

Round transitions and mixing remain in their existing domains. Network play continues to synchronize the chosen target’s ID/text/color; difficulty is setup/catalog metadata and is not added to the wire protocol or displayed on client gameplay screens in this change.

### Allowed Dependencies

SwiftUI, Observation, Foundation, existing ColorRequest/ColorData, CustomRequestStore and GameViewModel. Dependency direction remains model/data → store → view model → settings. Storage does not depend on UI or network types.

### Revalidation Triggers

Recheck existing request selection, defaults migration and invalid-data handling when fields/filtering change. Recheck host authority and target mirroring when integrating round start. Adding a client-visible difficulty label later would require an explicit network metadata contract.

## Architecture

### Existing Architecture Analysis

ColorRequest currently contains ID, text and target. CustomRequestStore keeps `{id,text,hex}` records in `customColorRequests.v1`. GameViewModel assembles the complete catalog, selects an ID or Random, and saves before publishing new requests. Settings already provides the request picker and entry sheet. Existing callers and tests construct requests without a level and consume the full availableRequests catalog.

### Architecture Pattern & Boundary Map

Extend those components directly. Retain availableRequests as the complete catalog for caller compatibility; add requestsForSelectedLevel for the settings picker and round target resolution. No repository layer or additional persistence system is needed.

### Technology Stack

Existing Swift 5, SwiftUI and Observation, plus Codable/UserDefaults. No package or deployment-target change.

## File Structure Plan

| File | Responsibility |
| --- | --- |
| ColorGameTesting/ColorData.swift | RequestDifficulty enum, ColorRequest defaulted level, initial classification of seven requests |
| ColorGameTesting/CustomRequestStore.swift | Optional persisted level field, legacy fallback, per-record level validation |
| ColorGameTesting/GameViewModel.swift | Selected level, filtered choices, save/select integration and level-restricted round selection |
| ColorGameTesting/Views/SettingsView.swift | Settings and Add Request level selectors |
| ColorGameTestingTests/CustomRequestStoreTests.swift | Existing save/reload regression checks |
| ColorGameTestingTests/RequestDifficultyTests.swift | Grouped level classification, filtering, persistence/legacy records, authority and New Round checks |
| ColorGameTestingTests/ColorDataTests.swift | Complete disjoint classification and unchanged IDs/text/colors |
| ColorGameTestingTests/GameViewModelTests.swift | Level filtering, explicit/Random choice and New Round retention |
| ColorGameTestingTests/GameViewModelLocalPlayTests.swift | Host/client authority preservation |
| ColorGameTestingTests/SettingsViewLocalPlayTests.swift | Level controls and host-only setup presentation |

## Components and Interfaces

### Catalog

`RequestDifficulty: Int, CaseIterable` has level1/level2/level3 with stable values 1/2/3 and display names. ColorRequest adds `difficulty: RequestDifficulty`, defaulting to level1 in its initializer so existing snapshots, fixtures and callers remain valid. Built-in declarations explicitly assign the approved classification.

Classification is temporary metadata, not a claim of measured pigment-matching difficulty. A single field on each built-in declaration makes later regrouping simple.

### Local Store

Keep the existing storage key. Extend the Codable Record with an optional integer difficulty. Missing values load as level1. Unknown integer levels omit only the affected record; valid neighbors survive. Save writes the request’s level. Identity/text/hex validation and save-before-publish behavior remain unchanged.

The optional integer avoids an unknown enum value invalidating an otherwise decodable entire array. Structurally undecodable payloads retain the existing empty-custom-list fallback.

### View Model

- `availableRequests`: full built-in plus local custom catalog, preserving existing ordering.
- `selectedRequestLevel`: starts at level1; changes are allowed only during settings with local rule authority. Changing it clears an incompatible selected ID and publishes through the existing host hook.
- `requestsForSelectedLevel`: read-only filtered catalog; both Picker and confirmSettings use it.
- Selecting a known request ID through the existing public selection property also selects that request’s level during settings. This preserves explicit-selection callers while keeping the picker consistent.
- `addCustomRequest(text:hex:difficulty:)`: optional difficulty defaults to current settings level, preserving existing two-argument calls. Save first; only on success publish the request, its level and selected ID.
- New Round clears request selection and resets Manual as before, while selectedRequestLevel remains a view-model setup value outside the reset GameState.
- No cross-level fallback at round start. If a filtered pool is empty, Start is unavailable. All three initial built-in pools are nonempty.

### Settings

Add a three-option level selector above Color Request with an accessible selected value. Random is described as using the selected level. The Add Request form owns a local level choice initialized from the current settings level and passes it to the existing save action. Existing preview, invalid-input handling, Add and Cancel remain unchanged.

### Network Integration

Only solo/host has mutation authority. Clients retain their local catalogs and cannot choose levels. The selected target travels through the current snapshot unchanged. Reconstructed client round targets may use the constructor’s default catalog level; client UI neither displays nor consumes that metadata. No protocol migration is required for this scoped setup feature.

## Requirements Traceability

| Criteria | Components/contracts |
| --- | --- |
| 1.1, 1.2, 1.3, 1.4 | Settings request form, preview and Add eligibility |
| 2.1, 2.2, 2.3, 2.4 | GameViewModel validation/authority and ColorHex |
| 3.1, 3.2, 3.3, 3.4 | CustomRequestStore save/load and invalid-record behavior |
| 4.1, 4.2, 4.3, 4.4 | Filtered catalog, selected ID and confirmSettings integration |
| 5.1, 5.2, 5.3 | Catalog classification, selected level and filtering |
| 5.4, 5.5, 5.6 | Form level, save/select and backward-compatible storage |
| 5.7, 5.8, 5.9 | Retained setup level, existing authority/network flow and unchanged game rules |

## Data Models

Domain: ColorRequest `{id,text,targetSRGB,difficulty}`. Storage: existing array `{id,text,hex,difficulty?}`. The level is a stable integer; legacy absence means level1. Built-in and custom requests remain one catalog. No new network payload or persisted session state.

## Error Handling

Keep existing name/hex validation. Invalid level records are omitted individually. A failed save leaves the catalog, selected level and request unchanged. Level changes and additions from clients or outside setup are rejected. An empty selected-level pool cannot silently choose from another pool.

## Testing Strategy

- Verify all seven existing IDs/text/targets remain and each occurs in exactly one approved group (5.1).
- Verify changing levels filters built-in/custom choices and clears incompatible selections; explicit selection can choose its known level; Random never escapes the current group (4.1, 4.3, 4.4, 5.2, 5.3).
- Save/reload one request at each level; load pre-level records without losing identity/target; omit unknown-level records without discarding valid neighbors; retain malformed-payload coverage (3.1–3.4, 5.5, 5.6).
- Verify Add defaults to current level, can save into another level, switches/ selects only after success, and keeps existing validation (1.1–2.4, 4.2, 5.4, 5.5).
- Verify New Round retains the level and still resets Manual; clients cannot mutate level/catalog and target snapshots preserve selected ID/text/color without catalog writes (5.7, 5.8, 5.9).
- Run focused existing request/setup/authority tests and macOS/iOS builds after integration.

## Implementation Plan for Approval

1. Add typed levels and backward-compatible local persistence, with classification and migration checks.
2. Integrate level selection/filtering with settings, custom entry and round target selection, preserving existing callers and authority.
3. Verify request selection, saved data and solo/network integration; build both platforms.

The user approved these steps and the design. Existing completed baseline tasks stay recorded; the existing malformed-storage regression is included in the grouped extension checks.

## Request deletion update

Solo players and the host may delete built-in or custom requests from the settings library. Custom entries are removed from saved records; built-in deletions are stored as stable ID exclusions on that device. Clear deleted selections and cached selection queues. Deletion is settings-only and does not change active rounds or guest libraries. Empty configured levels disable Start Run and show guidance to add requests or edit the schedule.
