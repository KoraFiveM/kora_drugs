---
title: Features
sidebar_position: 2
---

# Features

Everything here is derived from the code. Locations, labels, recipes and prices are not hard coded: they come from rows in the `kora_drugs` table, edited through the [Drug Creator](./creator.md). On a fresh install nothing is placed until an admin creates it or `Config.storage.exampleData` is enabled (see [Configuration](./configuration.md)).

## Steps

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

## Plant picking

Each `Type:pick` row defines a plant type: prop `model`, reward `item`, `maxGive`, `respawnTime` (seconds), `pickingData` (progress time, animation, disabled controls), optional `icon`, `targetLabel`, `progressLabel`, and `disabled`. The `locations` column lists spots (`coords`).

- The client spawns the prop at every free spot with a `kora_target` entity option.
- Picking runs a progress bar, then fires `kora_drugs:server:pick<Type>` with the spot index.
- The server checks the per-player `pick` cooldown, that the spot exists and is not taken, and that the player is within 3.0 units. It marks the spot taken, broadcasts `plantTaken`, gives a random 1 to `maxGive` of the item through `kora_inventory`, and respawns the spot after `respawnTime` seconds.
- Disabled plant types are not loaded. Creating, saving or deleting a plant reloads it for everyone (`plantsReload`, `plantsRemove`).

## Crafting steps

Bench steps are `kora_target` box zones (or spawned props when a location has an `object`). Using one starts a progress bar from the step data, then fires `kora_drugs:server:craft` with the drug, step and location index.

The server accepts the request only for a known craft step or a step whose data has `custom = true`, checks that the player is within 5.0 units of the saved location, applies the `craft` cooldown (2.5 s), then runs the step's recipe: it checks and removes the `give` items (items marked `keep` are only checked), then adds the `receive` item. A recipe is chosen from `data.recipe` or the default for the step; if no recipe exists the step does nothing. See [Drug Creator](./creator.md#recipes).

Default recipe ids per step are in `shared/steps.lua` (for example `Cocaine:powder` uses `Cocaine:powder`, `Meth:pour` uses `Meth:cook`).

Location entries may carry a `gang`; only players of that gang (from `kora_core` player data) get the target.

## Labs

`Cocaine:lab`, `Weed:lab` and `Meth:tele` define entrances. Each entry has `enter`, `exit` and optionally `gang`. The "Enter" target calls the `Tele` callback; the server checks the player is within 5.0 units of the door, remembers the original routing bucket, moves the player into bucket `old + key` and the client fades them to the exit. The exit target calls `TeleOut` and restores the bucket. The first lab's exit is used if the session was lost (for example after a restart). If `bob74_ipl` is started, the cocaine and meth lab interiors are configured by the client.

## Weed

Weed has extra server logic on top of the generic crafting:

- **Drying** (`Weed:drying`) turns the recipe result (`dried_cola` in the example recipes) into an item with random metadata: strain, classification (sativa or indica), grams (10 to 28), `thc` (10 to 30 percent) and `cbd` (5 to 20 percent). Ranges are in `shared/constants.lua` (`WeedPercents`).
- **Break nugs** (`Weed:breakNugs`) turns one `dried_cola` into nug items of its strain, one per gram, carrying `thc` and `cbd`.
- **Bag weed** (`Weed:bagWeed`) converts the whole stack of the first strain nug found into 1 g bags, consuming one `gram_bag` per nug and keeping `thc` and `cbd`.
- **Rolling** - using `rolling_paper` (registered through `kora_core`) with a nug in the inventory runs a 5 s progress bar and gives the matching joint.

Strains: Purple Haze, AK-47, Amnesia (sativa); Skunk, OG Kush, Blue Dream (indica). Item names are in [Items](./items.md).

## Meth cook

The meth chain is a server-validated minigame (`pour`, `heat`, `smash`, `bag`). The server keeps one cook session per player:

1. `qb-drugs:server:startCook` - near the pour station, consumes the `Meth:pour` recipe, starts a session.
2. `qb-drugs:server:runDials` - at least 5 s after pouring, near the heat station.
3. `qb-drugs:server:smash` - at least 5 s after heating, near the smash station.
4. `qb-drugs:server:getMeth` - at least 5 s after smashing, 25 s after the start, near the bag station; runs the `Meth:bag` recipe and ends the session.

`qb-drugs:server:explosion`, disconnecting and finishing all clear the session. `Meth:heat` has an `explosion` flag used by the client.

## Corner selling

`/cornerSell` toggles selling. While on, the client looks for a human, non-player ped within 10.0 units that is not in a vehicle and has not been used before, walks it to the player and adds a "Sell to buyer" target.

- The server callback `kora_drugs:getSellableItem` picks the first inventory item that appears in the `CornerSelling:settings` `pricing` table and builds the offer: amount is the stack size capped by `maxSell`, price is the configured price.
- For the twelve weed items (1 g bags and joints) with `weedPercentAdjustable` not `false`, the price is adjusted by the item's `thc` and `cbd` metadata: the average quality (0 to 1) maps to a swing of plus or minus `weedPercentFlow` (default 0.2).
- The player accepts or denies in a small NUI offer. Accepting plays a handshake and fires `kora_drugs:sellToBuyer` with the ped network id. The server resolves the ped (within 5.0 units), removes the items and pays cash through `kora_core`. A ped that already bought from the player is refused.

Settings `ripOff` and `minPolice` can be saved in the creator but no code reads them (see [Troubleshooting](./troubleshooting.md)).

## Dealers

Dealers are rows in the `dealers` table (name, coords, open hours). Admins manage them with `/newdealer`, `/deletedealer`, `/dealers` and `/dealergoto` (see [Commands](./commands.md)).

- Every dealer gets a `kora_target` box with **shop** and **Request delivery** options.
- **Shop** - a `kora_inventory` shop `kora_drugs-dealer-<id>` stocked from `LegacyDealerConfig.Products`. Access, buying and reputation (`dealer` rep versus the product `minrep`) are enforced on the server through `kora_inventory` hooks; the shop is closed outside the dealer's hours, outside the default routing bucket, or more than 5 units away. Opening hours use `GlobalState.kora_weathersync.hour`; without it dealers are always closed.
- **Delivery** - one active delivery per character is stored in `kora_drugs_deliveries`. The server chooses (or validates the client's legal choice of) item, amount (1 to 3) and location from `LegacyDealerConfig`, gives the items through an inventory exchange, and sets a deadline of `deliverySeconds` (default 300) from issue. The player drives to the location and uses "Deliver package". Settlement takes the carried items, pays cash (or a `markedbills` item when `UseMarkedBills` is on), changes `dealer` reputation, and applies the late, wrong-amount and police multipliers from the config. Settlement is idempotent: retrying a completed delivery returns the stored result.
- Deliveries survive reconnects (`kora_drugs:server:resumeDelivery`). Mail is sent through `qb-phone:sendNewMailToOffline` when `kora_phone` or `qb-phone` is started; failures are logged and never affect rewards.
