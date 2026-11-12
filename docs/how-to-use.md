---
title: "How to use"
sidebar_position: 3
---


# How to use

Every craftable step, lab entrance, plant type, corner-selling price list and recipe is a row in the `kora_drugs` table keyed by `"<Drug>:<step>"` (for example `Cocaine:powder`, `Weed:lab`, `CornerSelling:settings`). The server loads them into a `Drugs` table and a few `GlobalState` keys, and the client builds `kora_target` zones from whatever is published — so editing a row in the creator (or the database directly) changes the world without a restart.

## The Drugs table and live reload

On boot `server/events.lua` reads every row and builds `Drugs[drug][step] = { data, locations }`, and publishes everything except the server-only `CornerSelling` and `Custom` drugs to `GlobalState.Drugs`. The client (`client/_functions.lua`) waits for that global state, then listens for `kora_drugs:client:drugsReload` to patch individual steps.

- Call the server export `exports.kora_drugs:ReloadEvents(name?)` after writing to `kora_drugs` outside the creator (direct SQL, a seed script) to re-read one step (or every step with no argument) and re-broadcast it.
- Built-in steps (`EventSteps` in `server/events.lua`) always exist, even with empty data/locations, so a client zone-builder never has to guard against a missing key. Custom drugs created in the creator are not in that list; the client's `watchCustom` path picks them up instead, driven by `entry.data.custom == true`.
- `OnDrugs(drug, step, listener)` (client) registers a listener that fires immediately with the current entry (or `nil`) if the global state has already loaded, and again on every future reload — this is how every craft-step zone in this resource rebuilds itself.

## Crafting a step

A craft station is a `kora_target` zone built from a step's `locations`. Selecting it runs the configured progress bar (or a custom "step hook" scene, such as the cocaine cutting/bagging animations) and then asks the server to apply the recipe.

```text title="client → server (simplified)"
-- client: client/_functions.lua craftTrigger()
TriggerServerEvent('kora_drugs:server:craft', drug, step, key)

-- server: server/craft.lua
RegisterNetEvent('kora_drugs:server:craft', function(drug, step, key)
    -- re-checks the step exists, the saved location, distance and a 2.5s cooldown
    -- then looks up the recipe and calls craft(src, recipe)
end)
```

- The recipe used comes from `stepRecipe(name, data)` (`shared/steps.lua`): it prefers `data.recipe` if that id exists in the saved `Recipes:settings` row, otherwise a hard-coded default (`defaultRecipes`).
- `craft(src, recipe, meta?)` (`server/_functions.lua`) checks every `recipe.give` item is present (`hasItems`), removes each one not marked `keep`, and adds `recipe.receive` (with optional `meta` as item info, e.g. weed THC/CBD). It returns falsy and does nothing if any required item is missing or a removal fails partway — there is no table/money reward, only inventory items.
- Some steps are **hooks** instead of plain recipes: `stepHooks[name].handler` (server) or `.run`/`.check` (client) fully replace the default flow — used by Weed drying/breakNugs/bagWeed (which build custom items from the picked plant's THC/CBD/strain) and by the cocaine cutting/bagging cutscenes.
- Distance and cooldown are enforced server-side (`isNear`, a 2.5s shared `craft` cooldown bucket) regardless of what the client sends; five rejections against the same cooldown key drop the player.

## Labs with an enter/exit routing bucket

Cocaine, Meth and Weed each have a lab with one or more entrance doors and one exit, stored as a `"<Drug>:lab"` / `"Meth:tele"` row. Entering moves the player into a private routing bucket (offset by the door's index) via `RegisterLabTeleport`; leaving restores their previous bucket.

- Server callbacks `kora_drugs:<name>:Tele` / `kora_drugs:<name>:TeleOut` (registered once per lab by `RegisterLabTeleport(name, drug, step)`) check the player is standing within 5m of the saved `enter`/`exit` coordinates before changing the bucket — a client cannot simply request the interior.
- If the resource restarts while a player is inside, `TeleOut` falls back to the first configured lab's exit (no `old` bucket exists to restore to), so the player still gets out.

## Plant picking

Any step whose name ends in `:pick` (for example `Weed:pick`, `Cocaine:pick`, `Shrooms:pick`) is a plant type: a set of spots that spawn a prop, give an item on pickup, and respawn after `data.respawnTime` seconds.

- Server (`server/plantSpawns.lua`) publishes `GlobalState.drugPlantTypes` (list of plant type names), `GlobalState[<type>]` (the spot list with `taken` flags) and `GlobalState[<type> .. 'Data']` (the step's `data` table).
- Picking fires `kora_drugs:server:pick<Type>` with the spot index; the server checks a pick cooldown, distance (3m) and that the spot is not already taken, then calls `exports.kora_inventory:addItem(src, data.item, math.random(1, data.maxGive or 1))`.
- Call the server export `exports.kora_drugs:ReloadPlants(type?)` after changing a `:pick` row outside the creator.

## Corner selling to NPCs

The client command `cornerSell` toggles a loop that finds a nearby non-player ped, walks the player's character to it, and opens a buy/deny offer built from one item the player is carrying that matches the (server-held) `CornerSelling:settings` price list.

- Pricing, `maxSell`, `minPolice` and weed-quality pricing come from the server-only `CornerSelling` drug entry — never sent to the client. Weed items get a price swing of `± weedPercentFlow` based on how close their THC/CBD are to `WeedPercents` (`shared/constants.lua`), unless `weedPercentAdjustable` is `false`.
- The sale itself is server-authoritative: `kora_drugs:getSellableItem` (callback) picks the item and amount and remembers it per player; `kora_drugs:sellToBuyer` (event) resolves the buyer ped from its network id, removes the item and pays cash. A player cannot sell the same buyer twice in a row (`hasSale[src][buyer]`).
- `Config.*` has no corner-selling fields; the `minPolice` field exists in the saved settings but this resource does not read it anywhere server-side — unclear whether it is meant for another resource.

## Meth: a four-stage minigame

Meth is the most stateful chain: pour → heat (a fishing-style dial minigame) → pick up tray → smash → bag, tracked per player in a server-side `stage` state machine (`server/Meth.lua`) that also enforces a minimum 5-second gap between stages and ignores a client resuming a stage it has not reached.

- Each stage has its own `kora_target` zone built from the `Meth:pour` / `Meth:heat` / `Meth:smash` rows (`Meth:bag` has no zone — its target is a prop spawned by the smash step).
- Failing the heat dial minigame (`Kora.minigames.play('fishing', ...)`) can trigger an explosion at the heat station if `location.explosion == true`, and always resets the cook via `qb-drugs:server:explosion`.
- The final bag step calls `qb-drugs:server:getMeth`, which re-validates every stage flag and the 5s gaps server-side before crafting — the client minigame result is never trusted on its own.

## Legacy dealers: shops and deliveries

`shared/legacy_dealers.lua` ports qb-drugs's original dealer-NPC feature: fixed-stock `kora_inventory` shops per dealer (seeded from `LegacyDealerConfig.Products`, 10 weed items/seeds by default) plus a delivery minigame paid through `exports.kora_inventory:ExecutePlayerExchange`.

- A dealer only answers (`available()`) while `GetPlayerRoutingBucket(src) == 0`, the player is within 5 units, and the current `kora_weathersync` hour falls in its open window (`time.min == time.max` means always open, but the hour must still exist: without `kora_weathersync` every dealer is closed).
- Buying from a dealer shop is gated by a `kora_inventory` hook registered on `openInventory` and `buyItem` for any shop id starting with `kora_drugs-dealer-`: besides `available()`, buying a specific item also requires the player's `dealer` reputation (`GetRep('dealer')`) to meet that item's `minrep`.
- A delivery is one row in `kora_drugs_deliveries` per citizen (a unique index on `active_citizenid` enforces only one active delivery at a time). `kora_drugs:server:beginDelivery` creates it, hands the package via a logged player-exchange, and mails the destination; `kora_drugs:server:finishDelivery` re-derives the payout server-side from elapsed time (late ⇒ `/OverdueDeliveryFee`), amount still carried (short ⇒ `/WrongAmountFee`) and on-duty police count (`* PoliceDeliveryModifier`), then books it — the client only ever supplies the delivery id.
- Admin-only chat commands manage the dealer roster: `/newdealer`, `/deletedealer`, `/dealers`, `/dealergoto` (registered through `core.Commands.Add(..., 'admin')`, i.e. the qb-core command framework, gated additionally by the same `isAdmin()` ACE check).

## Custom drugs, recipes and the creator cache

Anything beyond the built-in steps is a "custom" drug: its `data.custom == true` and it is recorded in the `Custom:settings` row (`{ drugs = [...], removed = [...] }`). Recipes for every craftable step — built-in or custom — live in one row, `Recipes:settings`, as `{ "<Drug>:<step>": { give, receive } }` and are rebuilt into `recipeInfo`/`recipeIds` (`shared/recipes.lua`) whenever that row changes, on both sides.

- The full creator payload (plants, corner-selling settings, custom drugs, recipes) is cached server-side for `Config.creator.cacheSeconds` (default 30s, `0` disables it) and invalidated on every write, so repeated `/drugCreator` opens by several admins do not each re-query everything.

## The in-game creator (/drugCreator)

An admin-only NUI tool (`kora_drugs:creator` app, opened by the command below) that edits every `kora_drugs` row without touching the database by hand: lab entrances/exits, per-step locations and target text/icons/animations, corner-selling prices, recipes (give/receive items), and custom drugs/events. It is organised into pages (Plants, Events, Corner Selling, Recipes, Custom) and is backed by about two dozen admin-gated callbacks under the `kora_drugs:creator:*` namespace (e.g. `kora_drugs:creator:save`, `kora_drugs:creator:event:save`, `kora_drugs:creator:recipes:set`).

- Every one of those callbacks is wrapped by a single `adminCallback()` helper (`server/creator.lua`) that re-checks `isAdmin(src)` before running the handler — there is no client-only gate.
- Numeric/text inputs are clamped and pattern-checked server-side (coordinates within ±10000, gang names `^[%w_%-]+$`, item/object names `^[%w_%-%.]+$`, animation names `^[%w_@%-%.]+$`, animation flags 0–65535, etc.) via the shared validators in `server/_functions.lua` (`trim`, `inRange`, `cleanName`, `cleanVec`).
- Saving a row calls `dbSave`/`dbDelete` (`server/_functions.lua`), which invalidates the creator cache and (through `server/events.lua`'s `refreshStep`) re-publishes only the steps whose database signature actually changed.
- The exact shape of each creator page's save payload (per-page field names) is UI-driven and not fully traced here — see `server/creator.lua` for the per-page validation if you are scripting against these callbacks directly rather than using the UI.


## Feature reference (from the code)

Everything here is derived from the code. Locations, labels, recipes and prices are not hard coded: they come from rows in the `kora_drugs` table, edited through the [Drug Creator](./creator.md). On a fresh install nothing is placed until an admin creates it or `Config.storage.exampleData` is enabled (see [Configuration](./configuration.md)).

### Steps

A **step** is one row in `kora_drugs`, named `Drug:step`. The server loads them into `GlobalState.Drugs` (except `CornerSelling` and `Custom`, which stay server-only) and pushes changes to clients with `kora_drugs:client:drugsReload`. Clients rebuild targets when a step changes, so creator edits apply without a restart.

Built-in steps that the server always knows about:

| Group | Steps |
| --- | --- |
| Cocaine | `Cocaine:lab`, `Cocaine:powder`, `Cocaine:cutting`, `Cocaine:bagging` |
| Crack | `Crack:cook`, `Crack:bagging` |
| Heroin | `Heroin:drying`, `Heroin:vials`, `Heroin:syringe` |
| Meth | `Meth:tele`, `Meth:pour`, `Meth:heat`, `Meth:smash`, `Meth:bag` |
| Weed | `Weed:lab`, `Weed:drying`, `Weed:breakNugs`, `Weed:bagWeed` |
| Settings | `CornerSelling:settings`, `Recipes:settings`, `Custom:settings` |
| Plants | any `Type:pick` row (for example `Weed:pick`, `Cocaine:pick`) |

### Plant picking

Each `Type:pick` row defines a plant type: prop `model`, reward `item`, `maxGive`, `respawnTime` (seconds), `pickingData` (progress time, animation, disabled controls), optional `icon`, `targetLabel`, `progressLabel`, and `disabled`. The `locations` column lists spots (`coords`).

- The client spawns the prop at every free spot with a `kora_target` entity option.
- Picking runs a progress bar, then fires `kora_drugs:server:pick<Type>` with the spot index.
- The server checks the per-player `pick` cooldown, that the spot exists and is not taken, and that the player is within 3.0 units. It marks the spot taken, broadcasts `plantTaken`, gives a random 1 to `maxGive` of the item through `kora_inventory`, and respawns the spot after `respawnTime` seconds.
- Disabled plant types are not loaded. Creating, saving or deleting a plant reloads it for everyone (`plantsReload`, `plantsRemove`).

### Crafting steps

Bench steps are `kora_target` box zones (or spawned props when a location has an `object`). Using one starts a progress bar from the step data, then fires `kora_drugs:server:craft` with the drug, step and location index.

The server accepts the request only for a known craft step or a step whose data has `custom = true`, checks that the player is within 5.0 units of the saved location, applies the `craft` cooldown (2.5 s), then runs the step's recipe: it checks and removes the `give` items (items marked `keep` are only checked), then adds the `receive` item. A recipe is chosen from `data.recipe` or the default for the step; if no recipe exists the step does nothing. See [Drug Creator](./creator.md#recipes).

Default recipe ids per step are in `shared/steps.lua` (for example `Cocaine:powder` uses `Cocaine:powder`, `Meth:pour` uses `Meth:cook`).

Location entries may carry a `gang`; only players of that gang (from `kora_core` player data) get the target.

### Labs

`Cocaine:lab`, `Weed:lab` and `Meth:tele` define entrances. Each entry has `enter`, `exit` and optionally `gang`. The "Enter" target calls the `Tele` callback; the server checks the player is within 5.0 units of the door, remembers the original routing bucket, moves the player into bucket `old + key` and the client fades them to the exit. The exit target calls `TeleOut` and restores the bucket. The first lab's exit is used if the session was lost (for example after a restart). If `bob74_ipl` is started, the cocaine and meth lab interiors are configured by the client.

### Weed

Weed has extra server logic on top of the generic crafting:

- **Drying** (`Weed:drying`) turns the recipe result (`dried_cola` in the example recipes) into an item with random metadata: strain, classification (sativa or indica), grams (10 to 28), `thc` (10 to 30 percent) and `cbd` (5 to 20 percent). Ranges are in `shared/constants.lua` (`WeedPercents`).
- **Break nugs** (`Weed:breakNugs`) turns one `dried_cola` into nug items of its strain, one per gram, carrying `thc` and `cbd`.
- **Bag weed** (`Weed:bagWeed`) converts the whole stack of the first strain nug found into 1 g bags, consuming one `gram_bag` per nug and keeping `thc` and `cbd`.
- **Rolling** - using `rolling_paper` (registered through `kora_core`) with a nug in the inventory runs a 5 s progress bar and gives the matching joint.

Strains: Purple Haze, AK-47, Amnesia (sativa); Skunk, OG Kush, Blue Dream (indica). Item names are in [Items](./items.md).

### Meth cook

The meth chain is a server-validated minigame (`pour`, `heat`, `smash`, `bag`). The server keeps one cook session per player:

1. `qb-drugs:server:startCook` - near the pour station, consumes the `Meth:pour` recipe, starts a session.
2. `qb-drugs:server:runDials` - at least 5 s after pouring, near the heat station.
3. `qb-drugs:server:smash` - at least 5 s after heating, near the smash station.
4. `qb-drugs:server:getMeth` - at least 5 s after smashing, 25 s after the start, near the bag station; runs the `Meth:bag` recipe and ends the session.

`qb-drugs:server:explosion`, disconnecting and finishing all clear the session. `Meth:heat` has an `explosion` flag used by the client.

### Corner selling

`/cornerSell` toggles selling. While on, the client looks for a human, non-player ped within 10.0 units that is not in a vehicle and has not been used before, walks it to the player and adds a "Sell to buyer" target.

- The server callback `kora_drugs:getSellableItem` picks the first inventory item that appears in the `CornerSelling:settings` `pricing` table and builds the offer: amount is the stack size capped by `maxSell`, price is the configured price.
- For the twelve weed items (1 g bags and joints) with `weedPercentAdjustable` not `false`, the price is adjusted by the item's `thc` and `cbd` metadata: the average quality (0 to 1) maps to a swing of plus or minus `weedPercentFlow` (default 0.2).
- The player accepts or denies in a small NUI offer. Accepting plays a handshake and fires `kora_drugs:sellToBuyer` with the ped network id. The server resolves the ped (within 5.0 units), removes the items and pays cash through `kora_core`. A ped that already bought from the player is refused.

Settings `ripOff` and `minPolice` can be saved in the creator but no code reads them (see [Troubleshooting](./troubleshooting.md)).

### Dealers

Dealers are rows in the `dealers` table (name, coords, open hours). Admins manage them with `/newdealer`, `/deletedealer`, `/dealers` and `/dealergoto` (see [Commands](./commands.md)).

- Every dealer gets a `kora_target` box with **shop** and **Request delivery** options.
- **Shop** - a `kora_inventory` shop `kora_drugs-dealer-<id>` stocked from `LegacyDealerConfig.Products`. Access, buying and reputation (`dealer` rep versus the product `minrep`) are enforced on the server through `kora_inventory` hooks; the shop is closed outside the dealer's hours, outside the default routing bucket, or more than 5 units away. Opening hours use `GlobalState.kora_weathersync.hour`; without it dealers are always closed.
- **Delivery** - one active delivery per character is stored in `kora_drugs_deliveries`. The server chooses (or validates the client's legal choice of) item, amount (1 to 3) and location from `LegacyDealerConfig`, gives the items through an inventory exchange, and sets a deadline of `deliverySeconds` (default 300) from issue. The player drives to the location and uses "Deliver package". Settlement takes the carried items, pays cash (or a `markedbills` item when `UseMarkedBills` is on), changes `dealer` reputation, and applies the late, wrong-amount and police multipliers from the config. Settlement is idempotent: retrying a completed delivery returns the stored result.
- Deliveries survive reconnects (`kora_drugs:server:resumeDelivery`). Mail is sent through `qb-phone:sendNewMailToOffline` when `kora_phone` or `qb-phone` is started; failures are logged and never affect rewards.
