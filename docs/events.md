---
title: Events
sidebar_position: 8
---

# Events

These are internal to the resource's client and server flow, except where stated. Do not trigger server events from other resources: each handler validates distance, cooldowns and state, and a failed check silently ignores the request (or kicks, see cooldowns below).

## Server events

| Event | Payload | Behaviour |
| --- | --- | --- |
| `kora_drugs:server:craft` | `drug`, `step`, `key` | Runs a step's recipe. Requires a known or custom step, a saved location within 5.0 units, and the 2.5 s `craft` cooldown. |
| `kora_drugs:server:pick<Type>` | `id` (spot index) | One event per loaded plant type (for example `kora_drugs:server:pickWeed`). Requires the `pick` cooldown, a free spot and distance within 3.0. |
| `kora_drugs:sellToBuyer` | `netId` | Completes the pending corner-sell offer with a ped within 5.0 units that has not bought before. |
| `qb-drugs:server:getMeth` | none | Finishes a meth cook after all stages, see [Features](./how-to-use.md#meth-cook). |
| `qb-drugs:server:explosion` | none | Clears the player's meth cook session. |
| `qb-drugs:server:dealerShop` | `name` | Opens a dealer's shop if the dealer is open and within 5 units. |
| `qb-drugs:server:giveDeliveryItems` | dealer name or a table `dealer`, `item`, `amount`, `coords` | Begins or resumes a delivery. The server validates any client choice against `LegacyDealerConfig`. Rate limited to one call per 500 ms per player. |
| `qb-drugs:server:successDelivery` | table with `id` | Settles the active delivery. Rate limited like the above. |
| `qb-drugs:server:updateDealerItems` | ignored | Only refreshes the client's dealer list; stock is never changed here. |

Cooldown note: `onCooldown` counts how often a player is blocked by the same cooldown. On the fifth block the player is dropped from the server with a message naming the cooldown.

## Server callbacks (`Kora.callback`)

| Callback | Purpose |
| --- | --- |
| `kora_drugs:cocaine:Tele`, `kora_drugs:cocaine:TeleOut`, `kora_drugs:weed:Tele`, `kora_drugs:weed:TeleOut`, `kora_drugs:meth:Tele`, `kora_drugs:meth:TeleOut` | Lab entry (`key` = entrance index) and exit, see Labs in [Features](./how-to-use.md). |
| `kora_drugs:getSellableItem` | Builds the corner-sell offer. |
| `qb-drugs:server:startCook`, `qb-drugs:server:runDials`, `qb-drugs:server:smash` | Meth cook stages. Return `true` or `false, reason`. |
| `kora_drugs:server:beginDelivery`, `kora_drugs:server:finishDelivery`, `kora_drugs:server:resumeDelivery` | Dealer deliveries; each rate limited to 4 calls per 10 s. |
| `qb-drugs:server:RequestConfig` | QB-style callback returning the dealer roster. |
| `kora_drugs:creator:*` | Admin-only creator callbacks (`open`, `list`, `get`, `create`, `save`, `delete`, `event:get`, `event:save`, `event:delete`, `event:restore`, `corner:get`, `corner:search`, `recipes:get`, `recipes:search`, `recipes:set`, `recipes:create`, `recipes:receive`, `recipes:delete`, `custom:get`, `custom:drug:create`, `custom:drug:delete`, `custom:event:create`, `custom:event:delete`). |

## Client events and callbacks

| Event | Payload | Behaviour |
| --- | --- | --- |
| `kora_drugs:client:drugsReload` | `drug`, `step`, `entry` | A step changed; targets for it are rebuilt. |
| `kora_drugs:client:plantsReload` | `name`, `settings`, `spots` | A plant type was created or changed. |
| `kora_drugs:client:plantsRemove` | `name` | A plant type was removed. |
| `kora_drugs:client:plantTaken<Type>` / `kora_drugs:client:plantRespawned<Type>` | `id` | Hide or show the plant at a spot. |
| `kora_drugs:creator:open` | none | Opens the creator (only accepted from the local resource side). |
| `kora_drugs:client:delivery` | delivery table | Starts the delivery route (ignored unless sent by the server). |
| `kora_drugs:client:deliveryFinished` | result table | Shows the settlement result. |
| `qb-drugs:client:RefreshDealers` | roster | Rebuilds dealer targets. |
| `qb-drugs:client:setLocation` | ignored | From the mail button: recovers the active route from the server. |
| `qb-drugs:client:rolling` (callback) | none | Runs the rolling progress bar; returns whether it finished. |

## Events listened to from other resources

| Event | Side | Use |
| --- | --- | --- |
| `kora_core:server:playerLoaded` | server | Sends the `/drugCreator` suggestion. |
| `chat:init` | server | Resends the suggestion after the chat resource restarts. |
| `kora_inventory:server:ready` | server | Re-registers dealer shops and hooks. |
| `onResourceStop` (`kora_inventory`) | server | Marks dealers not ready and closes shops. |
| `QBCore:Client:OnPlayerLoaded` / `OnPlayerUnload` | client | Loads or clears dealer targets and the active delivery. |
| `playerDropped` | server | Clears cooldowns, lab, cook, selling and dealer state for the player. |

## Events sent to other resources

| Event | Use |
| --- | --- |
| `chat:addSuggestion`, `chat:removeSuggestion` | Admin suggestion for `/drugCreator`. |
| `chat:addMessage` | `/dealers` output. |
| `qb-phone:sendNewMailToOffline` (export) | Delivery mails when a phone resource is started. |
