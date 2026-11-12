---
title: Troubleshooting
sidebar_position: 12
---

# Troubleshooting

- **Nothing appears in the world.** On a new install no steps exist. Create them in `/drugCreator` or enable `Config.storage.exampleData` once and restart. Check that the console did not show a `kora_sql` error.
- **A bench does nothing or says nothing.** A step with no recipe does nothing. There are no built-in recipes: add one on the Recipes page and select it on the step. Also check that the items exist in the shared items.
- **Targets are missing after editing the table by hand.** Call the `ReloadEvents` or `ReloadPlants` [export](./exports.md), or restart the resource.
- **`/drugCreator` says "Admin permission required".** The player needs the `command` ACE, see [Permissions](./permissions.md).
- **Dealers are always closed.** Opening hours read `GlobalState.kora_weathersync.hour`. Start `kora_weathersync`; it is not declared in the manifest.
- **Dealers fail to load on start.** A duplicate dealer name, invalid coordinates or invalid hours in the `dealers` table stops loading. Fix the row and restart.
- **`/cornerSell` says "You have no sellable items".** The player carries no item listed in the corner-sell price table. Add prices on the Cornerselling page.
- **`/cornerSell` errors with no corner-sell row.** If the `CornerSelling:settings` row has no `pricing`, the server's fallback is the global `CornerSelling`, which is not defined anywhere in this resource, so the callback errors. Save the Cornerselling page once (or enable the example data) to create the row.
- **`ripOff` and `minPolice` do nothing.** They are saved by the creator but not read by the selling code.
- **A player was kicked for a cooldown.** Hitting the same cooldown (`craft` or `pick`) five times drops the player. Clients that send events faster than the progress time do this.
- **Delivery stuck.** Deliveries persist per character. Rejoin: the route is restored with the original deadline. Do not delete rows in `kora_drugs_deliveries` or the inventory receipts.
- **Lab interiors look empty.** The cocaine and meth interior styling needs `bob74_ipl`, which is optional.
