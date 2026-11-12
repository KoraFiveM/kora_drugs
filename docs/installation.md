---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Drugs is the drug production and dealing stack: pickable raw plants, multi-step crafting chains (cocaine, crack, heroin, meth, weed), corner selling to NPCs, legacy "dealer" NPCs with deliveries, and an in-game admin creator tool that edits every location, recipe and setting without a restart. It depends on `kora_lib`, `kora_core`, `kora_sql`, `kora_inventory` and `kora_target`, and answers to the legacy export name `kora_drugs`/`qb-drugs`.

## Install Kora Drugs

1. **Add the folder** — Place `kora_drugs` in your resources directory and keep its name (consumers and the legacy compat layer refer to it by this name).

2. **Start its dependencies first** — The manifest loads `@kora_lib/init.lua` then `@kora_core/init.lua` as shared scripts, and `@kora_sql/init.lua` as the first server script. `kora_inventory` must already export `qb-inventory` (`HasItem`, `RemoveItem`, `AddItem`, `GetItemByName`, `CreateShop`, `OpenShop`, `GetInventory`, `RegisterHook`, `ExecutePlayerExchange`) and `kora_target` must provide `addBoxZone`/`addEntity`/`removeZone`/`removeEntity`.

   ```lua title="fxmanifest.lua"
   dependency 'kora_lib'
   dependency 'kora_core'
   dependency 'kora_sql'
   dependency 'kora_inventory'
   dependency 'kora_target'

   provide 'qb-drugs'

   shared_scripts {
       '@kora_lib/init.lua',
       '@kora_core/init.lua',
       'shared/config.lua',
       'shared/constants.lua',
       'shared/legacy_dealers.lua',
       'shared/recipes.lua',
       'shared/steps.lua'
   }
   ```

3. **Let it create its own tables** — On first boot the resource calls `Kora.sql.ensureTables` for three tables: `kora_drugs` (one row per step, e.g. `Cocaine:lab`, `Weed:pick`, `Recipes:settings`), `kora_drugs_deliveries` (legacy dealer delivery state) and `dealers` (legacy dealer NPC roster). Every server script waits on `KoraDrugsAwaitStorage()` before it reads these tables, so a blank database does not race a cold start.

4. **Decide on example data** — With `Config.storage.exampleData` left `false` (default) the resource starts with no steps configured at all — open `/drugCreator` as an admin to set up locations, recipes and corner-selling prices. Turn it on only once to seed the bundled example locations (weed/cocaine/heroin/meth labs and picking spots); turn it back off afterwards, otherwise a step you delete in the creator is re-added on the next start.

   ```lua title="shared/config.lua"
   storage = Kora.config.object({
       exampleData = Kora.config.boolean(false, { ... }),
   })
   ```

5. **Grant the admin ACE** — Every admin-only command and callback (`/drugCreator`, `/newdealer`, `/deletedealer`, `/dealers`, `/dealergoto`) checks the `command` ACE via `IsPlayerAceAllowed(src, 'command')`, the same check `isAdmin()` uses everywhere in this resource. Grant it the usual way, e.g. `add_ace group.admin command allow`.

## Optional integrations

- kora_weathersync — if `GlobalState.kora_weathersync.hour` exists, legacy dealers use it to gate their opening hours. Without it every dealer is closed, including dealers whose `time.min` equals `time.max`.
- qb-phone or kora_phone — legacy dealer deliveries send mail (`sendNewMailToOffline`) with a start-delivery button. If neither is started, mail is silently skipped.
- bob74_ipl — if started, the cocaine and meth lab client scripts upgrade the matching biker business interior (style/security/details) on load. Entirely optional and skipped if the resource is missing.
- chat (qb-chat or compatible) — the `/drugCreator` suggestion is pushed per admin player via `chat:addSuggestion`/`chat:removeSuggestion`, resynced every 30s and on `chat:init`/player load.

## Dependency details


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

## Setup checklist

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