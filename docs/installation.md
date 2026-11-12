---
title: Installation
sidebar_position: 3
---

# Installation

## Dependencies

Declared in `fxmanifest.lua`:

| Resource | Used for |
| --- | --- |
| `kora_lib` | `Kora.*` helpers: callbacks, NUI apps, notifications, progress bars, streaming, raycast, state |
| `kora_core` | Player data, shared items, money, usable items |
| `kora_sql` | Table creation (`ensureTables`) and queries |
| `kora_inventory` | Item checks, removal and grants (via its `qb-inventory` provider), dealer shops and exchanges |
| `kora_target` | Box zones and entity targets for every interaction |

Used by the code but not declared as a dependency (the `kora_weathersync` line in the manifest is commented out):

| Resource | Used for |
| --- | --- |
| `qb-core` export (the Kora compat layer) | `exports['qb-core']:GetCoreObject()` for dealers (player, reputation, commands, duty count) and as an item list source in the creator |
| `kora_weathersync` | `GlobalState.kora_weathersync.hour` for dealer opening hours |

Optional: `bob74_ipl` (cocaine and meth lab interiors), `kora_phone` or `qb-phone` (delivery mail), `chat` (admin suggestion for `/drugCreator`), `fft` (test runner, see below).

## Steps

1. Place the resource in your resources folder and ensure it after its dependencies:

   ```cfg
   ensure kora_lib
   ensure kora_sql
   ensure kora_core
   ensure kora_inventory
   ensure kora_target
   ensure kora_drugs
   ```

2. No SQL import is needed. On start the resource creates `kora_drugs`, `kora_drugs_deliveries` and `dealers` through `kora_sql` and adds missing columns to older tables. See [Database](./database.md).
3. Make sure every item the recipes, plants and corner prices use exists in the `kora_core` shared items. See [Items](./items.md).
4. Choose how to get content:
   - build it yourself in `/drugCreator` (see [Drug Creator](./creator.md)), or
   - set `Config.storage.exampleData = true` once to load the bundled example steps (see [Configuration](./configuration.md)).
5. Grant admins the `command` ACE so they can use the creator and dealer commands (see [Permissions](./permissions.md)).
6. Create dealers in game with `/newdealer` if you want them (see [Commands](./commands.md)).

## Tests

- `bash test/run.sh` runs the offline Lua tests in `test/` (dealers, creator cache, suggestion, storage). They do not start FiveM or touch a real database.
- `tests/checklist-crime.feature` holds `kora_qa` scenarios (`qa_feature 'tests/*.feature'`).
- `fft_hooks.lua` and `fft_hooks_server.lua` are loaded last and return immediately unless `setr fft_kora_hooks true` is set and the `fft` runner is started. They expose `fftVersion` and `fftAction` exports for the test runner only.
