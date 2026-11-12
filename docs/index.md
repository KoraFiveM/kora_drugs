---
title: kora_drugs
sidebar_position: 1
---

# kora_drugs

`kora_drugs` is the Kora drugs resource, a rewrite of `qb-drugs` (it declares `provide 'qb-drugs'` and keeps the legacy `qb-drugs:*` names). It combines four systems:

- **Production chains** - pick plants (coca, poppies, weed, shrooms, cactus and any plant an admin adds), then process the raw items at lab and bench locations through recipe-driven crafting steps (cocaine, crack, heroin, weed, meth and admin-made "custom drugs").
- **Drug Creator** - an admin-only `kora_lib` NUI app (`/drugCreator`) that edits plants, step locations, recipes, corner-selling prices and custom drugs live, stored in the database.
- **Corner selling** - players sell drug items to passing NPCs with `/cornerSell`.
- **Dealers** - admin-placed dealers with a stock shop and timed package deliveries for reputation and cash.

Current version: see `version` in `fxmanifest.lua`.

## Documentation map

- [Installation](./installation.md) - dependencies, start order, first-run setup and tests
- [How to use](./how-to-use.md) - how steps, labs, plants, corner selling, meth, dealers and the creator work, plus a code-derived feature reference
- [Commands](./commands.md) - player and admin commands with examples
- [API reference](./api/index.md) - exports and creator callbacks
  - [Drugs data and live reload](./api/drugs-data.md) - `ReloadEvents`, `ReloadPlants`, `GetDealers` and test-hook exports
  - [Drug creator (admin tool)](./api/creator.md) - creator validation, caching and callbacks
- [Configuration](./configuration.md) - `shared/` config files and creator-managed settings
- [Drug Creator](./creator.md) - the admin app, its pages and validation limits
- [Events](./events.md) - net events, callbacks and listened events
- [Items](./items.md) - items the resource reads, gives and removes
- [Permissions](./permissions.md) - ACE and admin requirements
- [Database](./database.md) - tables and columns
- [Troubleshooting](./troubleshooting.md) - known caveats and common problems

## Layout

| Path | Purpose |
| --- | --- |
| `fxmanifest.lua` | Manifest, dependencies, script order |
| `shared/` | Config (`config.lua`), constants, dealer defaults, recipe loader, craft step table |
| `server/` | Storage schema, helpers, step reload (`events.lua`), crafting, plants, weed, meth, corner selling, dealers, creator |
| `client/` | Targets and zones, plant props, lab teleports, meth minigame, corner selling, dealers, creator UI |
| `fft_hooks.lua`, `fft_hooks_server.lua` | Optional test hooks, inert unless the `fft_kora_hooks` convar is `true` |
| `test/` | Offline Lua tests (`bash test/run.sh`) |
| `tests/` | `kora_qa` feature files (registered with `qa_feature`) |
