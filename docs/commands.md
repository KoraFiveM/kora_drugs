---
title: "Commands"
sidebar_position: 4
---


# Commands

Kora Drugs registers one admin UI command, one client-only toggle command, and four legacy dealer admin commands through the qb-core command framework.

## Built-in commands

### `/drugCreator`

Opens the drug creator NUI app for editing labs, craft steps, corner-selling prices, recipes and custom drugs.

| Field | Details |
| --- | --- |
| Context | In-game · server command |
| Arguments | No arguments. |
| Access | Server-side `isAdmin()` check: the `command` ACE (`IsPlayerAceAllowed(src, 'command')`). If missing, the player gets an "Admin permission required" notification and a server console warning is logged. |

**Example**

```text
/drugCreator
```

**Result**

Opens the `kora_drugs:creator` NUI app on the client, pre-loaded with the (possibly cached) creator payload.

### `/cornerSell`

Toggles corner-selling mode: finds a nearby NPC, walks to them, and opens a buy/deny offer for one sellable item.

| Field | Details |
| --- | --- |
| Context | In-game · client command |
| Arguments | No arguments. |
| Access | Any player — this is a client-only toggle with no server permission check. All of the actual sale logic (price, item removal, payment) is still enforced server-side; toggling it with nothing to sell simply ends the loop immediately. |

**Example**

```text
/cornerSell
```

**Result**

Prints "Looking for a buyer..." via textUI, then targets the found NPC with a "Sell to buyer" option.

### `/newdealer [name] [min] [max]`

Creates a legacy dealer NPC shop at the player's current position with the given opening-hour window.

| Field | Details |
| --- | --- |
| Context | In-game · server command (qb-core command framework) |
| Arguments | name — dealer name, letters/numbers/spaces/`_`/`-` only, max 50 chars, must be unused. min, max — opening hour bounds, 0–23 (equal values mean "always open"). |
| Access | Admin (`isAdmin()` ACE check; also registered with qb-core's `'admin'` permission level). |

**Example**

```text
/newdealer Downtown 20 4
```

**Result**

Inserts a `dealers` row at the player's coordinates and reloads the dealer roster for everyone.

### `/deletedealer [name]`

Deletes a legacy dealer by name.

| Field | Details |
| --- | --- |
| Context | In-game · server command |
| Arguments | name — an existing dealer's name. |
| Access | Admin. |

**Example**

```text
/deletedealer Downtown
```

**Result**

Removes the dealer row and its shop, and reloads the roster.

### `/dealers`

Lists every configured legacy dealer name in chat.

| Field | Details |
| --- | --- |
| Context | In-game · server command |
| Arguments | No arguments. |
| Access | Admin. |

**Example**

```text
/dealers
```

**Result**

A chat message with the sorted dealer names, comma-separated.

### `/dealergoto [name]`

Teleports the admin to a legacy dealer's coordinates.

| Field | Details |
| --- | --- |
| Context | In-game · server command |
| Arguments | name — an existing dealer's name. |
| Access | Admin. |

**Example**

```text
/dealergoto Downtown
```

**Result**

Moves the player ped to that dealer's saved coordinates.

## No in-game creator chat command for players

The `/drugCreator` suggestion is only ever pushed to admins (`server/creator_suggestion.lua`, resynced every 30s and on chat init / player load), so non-admins never see it exists even though the underlying `RegisterCommand` call itself is not ACE-restricted by FiveM — the resource's own handler is what turns non-admins away.

## Summary and notes

| Command | Who | Description |
| --- | --- | --- |
| `/cornerSell` | any player | Toggles corner selling. See [Features](./how-to-use.md#corner-selling). |
| `/drugCreator` | admins (ACE `command`) | Opens the [Drug Creator](./creator.md). Others get an "Admin permission required" notification and the attempt is logged as a warning. |
| `/newdealer name min max` | admins | Creates a dealer at your position. `name` is up to 50 characters of letters, digits, space, `_` and `-` and must be unique; `min` and `max` are opening hours 0 to 23 (an overnight window where min is greater than max is supported; equal means always open). Must be in routing bucket 0. |
| `/deletedealer name` | admins | Deletes the dealer. |
| `/dealers` | admins | Lists dealer names in chat. |
| `/dealergoto name` | admins | Teleports you to the dealer. |

The dealer commands are registered through the QB-style `Commands.Add` of the core compatibility layer with the `admin` permission, and each handler also checks `isAdmin` and ignores other callers. A roster change is refused while another one is running.
