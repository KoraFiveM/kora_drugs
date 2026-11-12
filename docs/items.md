---
title: Items
sidebar_position: 9
---

# Items

The resource adds no items itself: every item must exist in the `kora_core` shared items list. Which items a chain uses is defined by [recipes](./creator.md#recipes), plant rows and corner prices, plus the fixed names below, which are hard coded.

## Hard-coded item names

| Item | Where |
| --- | --- |
| `dried_cola` | Input of `Weed:breakNugs`; output of drying (recipe-defined) |
| `gram_bag` | Consumed one per nug by `Weed:bagWeed` |
| `rolling_paper` | Registered as usable; consumed when rolling a joint |
| `purple_haze_weed`, `ak47_weed`, `amnesia_weed`, `skunk_weed`, `og_kush_weed`, `blue_dream_weed` | Strain nugs. Metadata `thc`, `cbd` (and for dried cola `strain`, `grams`, `classification`) |
| `purple_haze_1g`, `ak47_1g`, `amnesia_1g`, `skunk_1g`, `og_kush_1g`, `blue_dream_1g` | Bagged weed, price-adjusted when corner selling |
| `purple_haze_joint`, `ak47_joint`, `amnesia_joint`, `skunk_joint`, `og_kush_joint`, `blue_dream_joint` | Joints from rolling, price-adjusted when corner selling |
| `markedbills` | Delivery payout when `UseMarkedBills` is on |
| `weed_brick`, `coke_brick` | Default delivery items |
| `weed_whitewidow`, `weed_skunk`, `weed_purplehaze`, `weed_ogkush`, `weed_amnesia` and their `_seed` variants | Default dealer shop stock |

## Example data items

With `Config.storage.exampleData` on, the example rows reference these items: `wet_cola`, `dried_cola`, `coca_leaf`, `coke_powder`, `cut_coke`, `cocaine_baggy`, `baking_soda`, `gram_bag`, `crack_rock`, `crack_bag`, `poppy_resin`, `heroin_powder`, `heroin_vial`, `heroin_syringe`, `empty_vial`, `metal_spoon`, `syringe`, `ephedrine`, `acetone`, `meth`, `shrooms`, `cactus_bulb`, `dried_mescaline`, and corner prices for the bagged weed and joints, `crack_bag`, `heroin_vial`, `cocaine_baggy` and `white_widow_joint`.

The README of the repository still contains an item definition snippet from the original resource. Check it against this list: for example it names `amensia_weed` while the code uses `amnesia_weed`, and it does not define `meth`, `rolling_paper`, `markedbills`, `shrooms` or `cactus_bulb`.

## Metadata

Weed items carry `info.thc` and `info.cbd` (strings such as `18%`). Dried cola also carries `strain`, `classification` and `grams`. Delivery payouts with marked bills store `info.worth`.
