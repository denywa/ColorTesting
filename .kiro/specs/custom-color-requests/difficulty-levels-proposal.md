# Request Difficulty Levels — Requirements Proposal

Status: requirements, design and implementation plan approved; implementation completed with focused checks. The modern UI workflow exception does not change approval rules for request selection and persistence.

## Purpose

Allow the developer to playtest three difficulty pools and add future requests to the appropriate pool. The seven original placeholder requests were removed after the new copywriting was added.

## Proposed Initial Classification

These are temporary playtesting groups, not measured difficulty ratings.

| Level | Current built-in requests |
| --- | --- |
| Level 1 — Easy | 40 new targets; see `docs/level-one-color-answer-key.md` |
| Level 2 — Medium | 23 new targets; see `docs/level-two-color-answer-key.md` |
| Level 3 — Hard | 40 new targets; see `docs/level-three-color-answer-key.md` |

## Acceptance Criteria

1. Settings provides three selectable levels, starting at Level 1 for a new app session.
2. The request selector lists built-in and saved custom requests belonging to the selected level.
3. Random selects only from the selected level. Changing levels clears a selected request from another level.
4. Add Color Request includes a level selector, initially matching the settings selection, alongside the existing text, hex color, validation and preview.
5. Saving a request persists its level with its text, target color and ID. The saved request is selected in its level and remains available after relaunch.
6. Previously saved requests without level information remain available in Level 1; existing saved IDs, text and colors are preserved.
7. Returning to settings for another round retains the chosen level for repeated testing; existing Manual Mix reset behavior remains unchanged.
8. In three-device play, only the host chooses the request level or adds requests. The resulting target continues to synchronize to all players; client custom catalogs remain local.
9. Manual/Auto mixing, color assignments, votes and scoring retain their existing behavior.

## Scope

Includes initial built-in classification, request filtering, per-level random selection, level-aware custom-request storage, and settings/form controls. New copywriting, new target colors, editing/deleting existing requests, and automatic difficulty estimation are outside this change.

## Verification

Focused checks cover partition completeness, filtering and random selection, changing levels, persistence/relaunch, loading older saved records, and host/client authority. Build both platforms once after integration.
