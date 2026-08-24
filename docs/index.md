---
layout: default
title: qbdrugs
---

Config-driven, multi-drug-type production/economy job for FiveM, built on
qbcore + qblib. Every drug in `Config.drugs` (weed and meth ship as examples)
is described entirely as data: an optional multi-stage **grow** phase
(`growStart` → `harvest`), any number of chemical/processing **convert**
stations (`processing`/`packaging`, input item → output item), and one or
more **sell** locations with a randomized per-unit payout range. A single
generic engine (`server/production.lua`) drives every drug through its
pipeline by branching only on the *station type* (`growStart`/`harvest`/
`convert`), never on a drug or stage name — adding a new drug is purely a
`config.lua` + `shared/items.lua` change, no Lua logic required. Each stage
can independently roll a cop dispatch alert (`Config.copAlertJobs`, via
`exports.qbcore:alert`), and the final packaged item of each drug carries a
`shared/items.lua` `effect` table (screen fx/anim/movement via qblib's
`QB.status`, plus a real overdose/addiction mechanic) that plays back the
moment a player uses it.

## Requirements

- [qblib](https://qbcore2.github.io/qblib/)
- [qbcore](https://qbcore2.github.io/qbcore/)
- [qbinventory](https://qbcore2.github.io/qbinventory/)
- [qbtarget](https://qbcore2.github.io/qbtarget/)

## Installation

`server.cfg`, in this order:
```
set mysql_connection_string "mysql://user:pass@localhost/qbcore?charset=utf8mb4"
ensure qbsql
ensure qblib
ensure qbcore
ensure qbinventory
ensure qbtarget
ensure qbdrugs
```
qbdrugs registers every item in `shared/items.lua` into qbcore's shared item
registry on boot (`exports.qbcore:registerShared`) and creates a
[qbtarget](https://qbcore2.github.io/qbtarget/)-style interact zone
(`QB.interact.addCircleZone`) for every station and sell location in
`Config.drugs` — no database import and no manual item setup needed.

## Usage examples

qbdrugs ships no exports and no player commands of its own — every station
and sell point is a `QB.interact` zone that a player walks up to and
interacts with, which fires the net events below. These examples show the
real client → server flow, and the config-driven way to extend the job.

### What firing a station action looks like (client → server)
This is the actual flow behind every station zone (`client/growing.lua`),
reused by `client/processing.lua`/`client/packaging.lua` for their own
station phases:
```lua
-- client, fired by QB.interact when a player uses a station's zone option
local token = QB.callback.trigger('qbdrugs:server:beginStation', 'weed', 'plant')
local completed = QB.progressbar.start({ label = 'Plant Weed Seeds', duration = 4000 })
TriggerServerEvent('qbdrugs:server:useStation', 'weed', 'plant', token, completed == true, nil)
```

### Sell a held stack of packaged drugs
Fired by every drug's sell-location zone (`client/selling.lua`); server-side
it sells the player's ENTIRE stack of that location's item in one shot:
```lua
-- client
TriggerServerEvent('qbdrugs:server:sell', 'weed', 1) -- drug name, sellLocations index
```

### Give a player everything needed to run the weed pipeline
```lua
-- server, e.g. from a test/admin resource
exports.qbcore:addItem(source, 'weed_seed', 1)
-- player then works plant -> harvest -> process -> package -> sell in-game
```

### React to a drug taking effect (custom feedback on top of the built-in toast)
`client/use.lua` already does this for its own toast — the same
`QB.status.onChange` hook is how any client script observes a use:
```lua
-- client
QB.status.onChange(function(name, applied)
    if not applied then return end
    local item = Drugs.itemsByName[name]
    if item then print(('%s is now in effect'):format(item.label)) end
end)
```

### Add a brand-new drug purely through config (no Lua changes)
Every field below is real schema (`config.lua`'s `QBDrugsConfig` annotations);
a synthesized drug like `meth` simply omits `growth` entirely:
```lua
-- config.lua
Config.drugs.coke = {
    label = 'Cocaine',
    pipeline = { 'process', 'package', 'sell' },
    stations = {
        process = {
            type = 'convert', phase = 'processing', label = 'Process Coke',
            coords = vector3(1020.0, -3190.0, -35.0), radius = 2.5, minigame = 'circuit',
            recipe = { inputItem = 'coke_leaf', inputAmount = 4, outputItem = 'coke_brick', outputAmount = 1 },
        },
        package = {
            type = 'convert', phase = 'packaging', label = 'Package Coke',
            coords = vector3(1025.0, -3190.0, -35.0), radius = 2.5, minigame = 'skillbar',
            recipe = { inputItem = 'coke_brick', inputAmount = 1, outputItem = 'coke_bag', outputAmount = 3 },
        },
    },
    sellLocations = { { coords = vector3(100.0, 200.0, 30.0), item = 'coke_bag', pricePerUnit = { min = 40, max = 90 } } },
    copAlerts = { process = { enabled = true, chance = 0.2 }, package = { enabled = true, chance = 0.1 }, sell = { enabled = true, chance = 0.45 } },
}
-- plus matching item defs (coke_leaf/coke_brick/coke_bag) added to Drugs.items in shared/items.lua
```

## API reference

qbdrugs is a leaf resource — it exposes no `exports`. Its surface is the net
events/callback below (client ↔ server) plus internal Lua tables
(`Drugs.*`, `Production.*`) shared only across its own client/server scripts.

### Net events
```lua
-- client -> server
TriggerServerEvent('qbdrugs:server:sell', drugName, locationIndex)
TriggerServerEvent('qbdrugs:server:useStation', drugName, stageName, token, completed, proof)
```

### Callback (via qblib's `QB.callback`)
```lua
-- client -> server, returns a short-lived token or (nil, errString)
QB.callback.trigger('qbdrugs:server:beginStation', drugName, stageName)
```

### `Drugs.*` (client, `client/growing.lua`)
```lua
Drugs.runStation(drugName, stageName, station)   -- runs the token/minigame-or-progressbar/useStation flow
Drugs.setupStation(drugName, stageName, station)  -- registers one station's QB.interact zone
Drugs.itemsByName[name]                           -- item def lookup (shared/items.lua)
```

### `Production.*` (server, `server/production.lua`)
```lua
Production.completeStage(src, drugName, stageName, coords)  -- dispatches on station.type; called by server/stations.lua
Production.startGrow(src, drugName)
Production.isReadyToHarvest(src, drugName)
Production.completeHarvest(src, drugName)
Production.completeConvert(src, drugName, stageName)
Production.rollYield(yieldCfg)          -- {min,max} range or QB.util.weightedChoice list
Production.rollCopAlert(drugName, stageName, coords)  -- routes a hit through exports.qbcore:alert
```

## Config highlights (`config.lua`)

- `Config.drugs.<name>` — one entry per drug: `label`, `pipeline` (ordered
  stage names, UI/documentation only), optional `growth`
  (`seedItem`/`growthStages`/`item`/`harvestYield`), `stations` (keyed by
  stage name, each a `type`/`phase`/`coords`/`radius`/`minigame`/`duration`/
  `recipe`), `sellLocations` (`coords`/`radius`/`item`/`pricePerUnit`), and
  `copAlerts` (per-stage `enabled`/`chance`, plus the special `sell` key).
- `Config.stationType` — the three generic station roles production branches
  on: `growStart`, `harvest`, `convert`.
- `Config.stationPhase` — `growing`/`processing`/`packaging`, a pure
  file-organization tag read by the matching client script.
- `Config.proximity.stationRadius` / `sellRadius` — default zone radii and
  the server-side re-check distance.
- `Config.copAlertJobs` — which job(s) `exports.qbcore:alert` dispatches to
  (default `{ 'police' }`).
- `Config.overdoseDamage` — flat HP loss on an overdose roll; per-item
  severity comes from that item's own `effect.overdoseChance`
  (`shared/items.lua`), not a second per-drug number.
- Shipped examples: `Config.drugs.weed` (grown, 5-stage pipeline,
  `harvestYield = {min=3,max=8}`) and `Config.drugs.meth` (synthesized, no
  `growth`, purely `convert` stations back to back).

## Related resources

Part of the [qbcore2](https://github.com/qbcore2) resource set:

- [qblib](https://qbcore2.github.io/qblib/) — shared helper library
- [qbsql](https://qbcore2.github.io/qbsql/) — database driver
- [qbcore](https://qbcore2.github.io/qbcore/) — framework core
- [qbinventory](https://qbcore2.github.io/qbinventory/) — headless inventory
- [qbtarget](https://qbcore2.github.io/qbtarget/) — targeting/interaction
- [qbclothing](https://qbcore2.github.io/qbclothing/) — clothing/wardrobe
- [full resource list ↗](https://github.com/orgs/qbcore2/repositories)
