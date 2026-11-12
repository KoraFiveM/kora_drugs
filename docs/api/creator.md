---
title: "Drug creator (admin tool)"
sidebar_position: 3
---


# Drug creator (admin tool)

## Server

Backs the `/drugCreator` NUI app. Every callback is wrapped by a single `adminCallback()` helper that re-checks the `command` ACE, so the permission boundary is enforced in exactly one place regardless of how many pages the UI adds.

Namespace: `server/creator.lua, client/creator.lua, server/creator_suggestion.lua` · Source: `server/creator.lua, server/creator_suggestion.lua`

### Validation

Coordinates are clamped to ±10000 per axis (`cleanVec`), rotation/heading to ±720° (`cleanPointCoords`), gang names to `^[%w_%-]+$`, item/object names to `^[%w_%-%.]+$`, animation names to `^[%w_@%-%.]+$`, animation flags to 0–65535, and free text is trimmed and length-capped. Fixed page limits: 200 plant spots, 50 event locations, 24 item search results per page, 500 corner-selling items, a $1,000,000 corner price cap, 20 recipe ingredients, and a 1000 recipe amount cap.

### Caching

The combined `/drugCreator` open payload (plants + corner + custom + recipes) is cached for `Config.creator.cacheSeconds` seconds (default 30, 0 disables caching) and invalidated on every save.

### Chat suggestion

When `Config.creator.chatSuggestion` is true, `/drugCreator` is pushed as a chat suggestion to each player individually as soon as they pass `isAdmin()`, and removed if they lose it — never broadcast to everyone, so non-admins cannot discover the command through chat autocomplete.

### Functions

No exports — about two dozen `kora_drugs:creator:*` callbacks (plants, events/steps, corner selling, recipes, custom drugs) plus the `drugCreator` command.

### Limits and related APIs

Server only. The per-page save payload shapes (exact field names expected by `kora_drugs:creator:event:save`, `:recipes:set`, etc.) are UI-driven and not fully enumerated here; read `server/creator.lua` directly before scripting against these callbacks.

## Client

Renders the creator as a `Kora.nui` app (`kora_drugs:creator`) with pages for Plants, Events (every built-in and custom craft step/lab), Corner Selling, Recipes and Custom drugs. Opened by the server event `kora_drugs:creator:open`.

Namespace: `server/creator.lua, client/creator.lua, server/creator_suggestion.lua` · Source: `client/creator.lua`

### Functions

No exports — UI state only.

### Limits and related APIs

Client only. 1500+ lines of NUI wiring; the event/location/recipe field definitions for every built-in step are declared in a static `EVENTS` table at the top of the file if you need the exact label/icon per step.
