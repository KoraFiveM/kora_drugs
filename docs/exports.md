---
title: Exports
sidebar_position: 7
---

# Exports

All exports are server side.

| Export | Arguments | Returns | Description |
| --- | --- | --- | --- |
| `ReloadEvents` | `name` (optional step such as `'Cocaine:lab'`) | boolean when a name is given, nothing otherwise | Re-reads one step from `kora_drugs`, or every step when no name is given. If the row changed it updates `Drugs` and `GlobalState.Drugs` and sends `kora_drugs:client:drugsReload` to all clients (settings kept server-only are not sent). |
| `ReloadPlants` | `plantType` (optional, for example `'Weed'`) | nothing | Reloads plant types from the database, republishes `GlobalState` and sends `plantsReload` for one or all types. |
| `GetDealers` | none | table keyed by dealer name | A detached copy of the dealer roster (`id`, `name`, `coords`, `time`, `products` with current stock). Also provided as `qb-drugs:GetDealers` through the Kora compat layer. |
| `fftVersion` | none | number | Only when `fft_kora_hooks` is `true`: version of the test hook. |
| `fftAction` | `action`, `src`, ... | `ok, result` | Only when `fft_kora_hooks` is `true` and called by the `fft` resource for an authorised session. Server action `cornerSelling` returns the corner prices; client actions `cornerPrice`, `cornerPriceSet` and `cornerPriceRemove` change one price through the creator callbacks. |

Run `ReloadEvents` or `ReloadPlants` after changing `kora_drugs` rows by hand. The creator already calls them on every save.
