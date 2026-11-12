---
title: Drug Creator
sidebar_position: 5
---

# Drug Creator

`/drugCreator` opens a 1200 by 800 `kora_lib` NUI app (`Drug Creator`) for admins. Its pages are **Plants**, one page per drug step, **Cornerselling**, **Recipes** and **Custom drugs**. All data is loaded in one callback (`kora_drugs:creator:open`) and saved to the `kora_drugs` table; each save reloads the affected step and pushes it to every client, so changes are live.

Every creator callback is admin only: the server checks `isAdmin` (the `command` ACE, see [Permissions](./permissions.md)) on each call, so the client UI is not trusted. Input is cleaned and range-checked on the server before saving.

## Plants

Create a plant type (name of letters and digits starting with a letter, prop model, reward item that must exist in the shared items), then edit it:

| Field | Limit |
| --- | --- |
| Model | letters, digits, `_`, `-`, `.`, up to 64 characters |
| Item | must exist in shared items |
| Max give | 1 to 100 |
| Respawn time | 1 to 3600 seconds |
| Pick time | 500 to 60000 ms |
| Animation dict, clip | up to 64 characters (letters, digits, `_`, `@`, `-`, `.`); flag 0 to 65535 |
| Disable | any of `move`, `combat`, `car`, `vehicle` |
| Disabled | hides the plant type and stops it loading |
| Spots | up to 200, placed by aiming at the world with the raycast tool |

Labels (`icon`, `targetLabel`, `progressLabel`) are trimmed to 64 characters. Deleting a plant removes its `Type:pick` row.

## Step pages

Each built-in step has a page with target label and icon, progress label, time (500 to 60000 ms), disabled controls, animation, and where it applies a list of locations (up to 50). Placement is done in game by aiming. Types:

- **Labs** (`Cocaine:lab`, `Weed:lab`, `Meth:tele`) - entrances with `enter` door, shared `exit`, optional `gang` (letters, digits, `_`, `-`, up to 32). Permanent: cannot be deleted.
- **Point steps** (`Cocaine:powder`, `Crack:cook`, `Crack:bagging`, `Heroin:drying`, `Heroin:vials`, `Heroin:syringe`, `Weed:drying`, `Weed:breakNugs`, `Weed:bagWeed`) - target points, optionally with a prop object and gang.
- **Fixed steps** (`Cocaine:cutting`, `Cocaine:bagging`) - text only; the position is fixed in code.
- **Meth stations** (`Meth:pour`, `Meth:heat`, `Meth:smash`, `Meth:bag`) - one position each with offset, rotation, size, bucket or explosion where relevant; defaults are seeded.

Steps with a recipe store the chosen recipe id in `data.recipe`. Built-in steps other than the permanent ones can be deleted; the step is then remembered in `Custom:settings.removed` so it is not re-created on start, and can be restored.

## Cornerselling

Edits `CornerSelling:settings`:

| Field | Limit |
| --- | --- |
| `maxSell` | 1 to 1000 |
| `ripOff` | 0 to 1 (stored, not used by the selling code) |
| `minPolice` | 0 to 100 (stored, not used by the selling code) |
| `weedPercentAdjustable` | on or off |
| `weedPercentFlow` | 0 to 1 |
| Prices | up to 500 items, each 0 to 1,000,000; item search shows up to 24 results |

## Recipes

A recipe is stored in `Recipes:settings` under an id of the form `Drug:name` (up to 48 characters). It has `give` (up to 20 distinct items, amount 1 to 1000, optional `keep` so the item is required but not consumed) and `receive` (an item that must exist and an amount of 1 to 1000; none means the step only consumes). Recipes are rebuilt on every save: deleting one removes it, adding one makes it available. There are no built-in recipes; with an empty recipe table crafting steps do nothing.

## Custom drugs

Create a drug name (letters and digits, starting with a letter, up to 24 characters, not equal to an existing drug) and add events to it (letters, digits, `_`, up to 24). A custom event is a point step saved with `custom = true`, so the server accepts crafting at it, and it can be given a recipe. Deleting a custom drug deletes its events. `Custom:settings` stays on the server only.

## Chat suggestion

When `Config.creator.chatSuggestion` is on, admins get `/drugCreator` in the chat suggestions. It is sent per player and rechecked every 30 seconds, so non-admins never see it and permission changes are picked up.
