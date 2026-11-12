---
title: Configuration
sidebar_position: 4
---

# Configuration

Configuration is split between code-level config files in `shared/` and settings stored in the database and edited through the [Drug Creator](./creator.md).

## `shared/config.lua` (`Config`)

Defined with `Kora.config.define`, so the values can also be changed through the Kora config system.

| Key | Type | Default | Live | Purpose |
| --- | --- | --- | --- | --- |
| `creator.cacheSeconds` | integer 0 to 600 | `30` | yes | How long the server reuses the data it sends when an admin opens `/drugCreator`. Any creator save clears it at once. `0` disables the cache. |
| `creator.chatSuggestion` | boolean | `true` | yes | Shows `/drugCreator` in the chat suggestion list, only to players who pass the admin check. |
| `storage.exampleData` | boolean | `false` | no | Adds the bundled example rows to `kora_drugs` on start. Existing rows are left alone. Leave it off once your own steps exist, otherwise a step you delete is added back on the next start. |

## `shared/constants.lua`

| Name | Purpose |
| --- | --- |
| `WeedPercents` | THC (10 to 30) and CBD (5 to 20) ranges used when weed is dried and when corner-sell prices are adjusted. |
| `ProgressDisableOptions` | Control options offered in the creator: `move`, `combat`, `car`, `vehicle`. |
| `DefaultProgress` | Fallback progress bar: 5000 ms, animation `mp_arresting` / `a_uncuff` flag 17, disabling move, combat and car. |

## `shared/legacy_dealers.lua` (`LegacyDealerConfig`)

Dealer defaults adapted from upstream `qb-drugs`.

| Key | Default | Purpose |
| --- | --- | --- |
| `deliverySeconds` | `300` | Time allowed for a delivery, from issue. |
| `UseMarkedBills` | `false` | Pay perfect deliveries as a `markedbills` item with `info.worth` instead of cash. |
| `DeliveryRepGain` / `DeliveryRepLoss` | `1` / `1` | `dealer` reputation change for a perfect or imperfect delivery. |
| `PoliceDeliveryModifier` | `2` | On a full, on-time delivery the payout is multiplied by the on-duty police count times this value (when police are on duty). |
| `WrongAmountFee` | `2` | Payout divisor when fewer items than ordered are handed over. |
| `OverdueDeliveryFee` | `4` | Payout divisor when the deadline passed. |
| `DeliveryItems` | `weed_brick`, `coke_brick` (payout 1000 each, `minrep` 0) | Items a delivery may ask for; `payout` is per item. |
| `DeliveryLocations` | five Los Santos locations | Possible destinations (`label`, `coords`). |
| `Products` | ten items (`weed_*` and `weed_*_seed`), price 15, amount 150, `minrep` 0 to 180 in steps of 20 | Stock of every dealer shop. |

The rule values are copied into each delivery when it is issued, so editing the config does not change deliveries already in progress. Dealers themselves (name, position, hours) are not in the config: they are rows in the `dealers` table.

## Creator-managed settings (database)

| Row | Contents |
| --- | --- |
| `Type:pick` | One plant type (model, item, give amount, respawn, progress, spots). |
| `Drug:step` | Step data (target label and icon, progress, animation, recipe id) and locations. |
| `CornerSelling:settings` | `pricing` (item to price), `maxSell`, `ripOff`, `minPolice`, `weedPercentAdjustable`, `weedPercentFlow`. |
| `Recipes:settings` | All recipes, see [Drug Creator](./creator.md#recipes). |
| `Custom:settings` | `drugs` (custom drug names) and `removed` (built-in steps an admin deleted and that must not be re-created). |

## Locales

Labels the server and client fall back to (`Kora.lang`, for example `Cocaine.powder.progress`, `Functions.no_items`) come from the Kora locale files. This repository ships no `locales/` folder, so those keys must be provided elsewhere or the step text from the creator is used instead.
