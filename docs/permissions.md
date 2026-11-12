---
title: Permissions
sidebar_position: 10
---

# Permissions

## ACE

Admin checks use `IsPlayerAceAllowed(src, 'command')`. Players need this ACE for:

- `/drugCreator` and every `kora_drugs:creator:*` callback,
- `/newdealer`, `/deletedealer`, `/dealers`, `/dealergoto` (also registered with the `admin` permission of the core command layer),
- the `/drugCreator` chat suggestion.

Example `server.cfg` line (adapt to your group setup):

```cfg
add_ace group.admin command allow
```

## Everything else

- No permission is needed to pick plants, craft, corner sell, use dealers or run the meth cook; access is limited by distance, items, cooldowns, reputation and opening hours.
- Location entries can carry a `gang`; only players of that gang (from `kora_core` player data) get the target or the lab door.
- Server events are protected by distance and cooldown checks. A player who hits the same cooldown five times is dropped.
