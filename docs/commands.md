---
title: Commands
sidebar_position: 6
---

# Commands

| Command | Who | Description |
| --- | --- | --- |
| `/cornerSell` | any player | Toggles corner selling. See [Features](./features.md#corner-selling). |
| `/drugCreator` | admins (ACE `command`) | Opens the [Drug Creator](./creator.md). Others get an "Admin permission required" notification and the attempt is logged as a warning. |
| `/newdealer name min max` | admins | Creates a dealer at your position. `name` is up to 50 characters of letters, digits, space, `_` and `-` and must be unique; `min` and `max` are opening hours 0 to 23 (an overnight window where min is greater than max is supported; equal means always open). Must be in routing bucket 0. |
| `/deletedealer name` | admins | Deletes the dealer. |
| `/dealers` | admins | Lists dealer names in chat. |
| `/dealergoto name` | admins | Teleports you to the dealer. |

The dealer commands are registered through the QB-style `Commands.Add` of the core compatibility layer with the `admin` permission, and each handler also checks `isAdmin` and ignores other callers. A roster change is refused while another one is running.
