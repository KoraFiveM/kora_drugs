---
title: "Drugs data & live reload"
sidebar_position: 2
---


# Drugs data & live reload

Owns the `Drugs` table (one entry per `"<Drug>:<step>"` row), publishes the non-server-only parts to `GlobalState.Drugs`, and offers the two reload exports every other part of this resource (and your own scripts) can call after writing to `kora_drugs` directly.

Namespace: `exports.kora_drugs / client Drugs table` · Source: `server/events.lua, server/_functions.lua`

## Functions

Two reload exports and one read-only roster export.

### `exports.kora_drugs:ReloadEvents(name?)`

Re-reads one `kora_drugs` step (or every step with no argument) from the database and re-broadcasts whatever changed to clients. Use after writing to the table outside the creator.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `name?` | string | A step key such as `'Weed:lab'`. Omit to rescan every known step plus any new rows. |

**Returns**

- **No return value. Steps whose signature did not change are not re-sent.**

**Example**

```lua
-- after a direct INSERT/UPDATE on kora_drugs for 'Weed:lab'
exports.kora_drugs:ReloadEvents('Weed:lab')
```

**Representative console output**

```text
Internally compares a cheap signature (`data` and `locations` JSON text) against the last seen value per step to avoid redundant broadcasts.
```

### `exports.kora_drugs:ReloadPlants(plantType?)`

Reloads plant-picking spots from every `"<Type>:pick"` row and republishes them. Use after changing a pick row outside the creator.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `plantType?` | string | A plant type name such as `'Weed'`. Omit to reload and re-broadcast every plant type. |

**Returns**

- **No return value.**

**Example**

```lua
exports.kora_drugs:ReloadPlants('Shrooms')
```

**Representative console output**

```text
Also updates `GlobalState.drugPlantTypes`, `GlobalState[type]` (spots) and `GlobalState[type .. 'Data']` (settings), and removes a type entirely if its row disappears or sets `data.disabled`.
```

### `exports.kora_drugs:GetDealers()  -- also exports['qb-drugs']:GetDealers()`

Returns the current legacy dealer roster with live stock counts, for resources that want to show dealer info outside this resource's own UI.

**Parameters**



**Returns**

- **dealers** — table keyed by dealer name: `{ id, name, coords, time = { min, max }, products }`, where each product carries its live `amount` read from the dealer's `kora_inventory` shop.

**Example**

```lua
local dealers = exports.kora_drugs:GetDealers()
for name, dealer in pairs(dealers) do print(name, dealer.coords.x, dealer.coords.y) end
```

**Representative console output**

```text
Server only. Also reachable through the legacy export name via `Kora.compat.provideExport('qb-drugs', 'GetDealers', roster)`.
```

## Limits and related APIs

Server only. `CornerSelling` and `Custom` steps are deliberately excluded from `GlobalState.Drugs` and from the `kora_drugs:client:drugsReload` event — they hold server-only pricing/admin data.

## Export summary (from the code)

All exports are server side.

| Export | Arguments | Returns | Description |
| --- | --- | --- | --- |
| `ReloadEvents` | `name` (optional step such as `'Cocaine:lab'`) | boolean when a name is given, nothing otherwise | Re-reads one step from `kora_drugs`, or every step when no name is given. If the row changed it updates `Drugs` and `GlobalState.Drugs` and sends `kora_drugs:client:drugsReload` to all clients (settings kept server-only are not sent). |
| `ReloadPlants` | `plantType` (optional, for example `'Weed'`) | nothing | Reloads plant types from the database, republishes `GlobalState` and sends `plantsReload` for one or all types. |
| `GetDealers` | none | table keyed by dealer name | A detached copy of the dealer roster (`id`, `name`, `coords`, `time`, `products` with current stock). Also provided as `qb-drugs:GetDealers` through the Kora compat layer. |
| `fftVersion` | none | number | Only when `fft_kora_hooks` is `true`: version of the test hook. |
| `fftAction` | `action`, `src`, ... | `ok, result` | Only when `fft_kora_hooks` is `true` and called by the `fft` resource for an authorised session. Server action `cornerSelling` returns the corner prices; client actions `cornerPrice`, `cornerPriceSet` and `cornerPriceRemove` change one price through the creator callbacks. |

Run `ReloadEvents` or `ReloadPlants` after changing `kora_drugs` rows by hand. The creator already calls them on every save.
