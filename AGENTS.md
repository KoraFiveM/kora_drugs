# kora_drugs agent guide

`kora_drugs` is the Kora drugs resource (a rewrite of `qb-drugs`): plant picking and recipe-driven processing steps stored in the `kora_drugs` table, an admin Drug Creator NUI (`/drugCreator`), NPC corner selling (`/cornerSell`) and dealers with shops and deliveries. Layout: `fxmanifest.lua`, `shared/` (config, constants, dealer defaults, recipe loader, craft steps), `server/` (schema, helpers, steps, crafting, plants, weed, meth, corner selling, dealers, creator), `client/` (targets, plants, labs, meth, corner selling, dealers, creator UI), `fft_hooks*.lua` (optional test hooks), `test/` (offline Lua tests) and `tests/` (kora_qa features).

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first (it has a documentation map). Layout: `index.md` (hub), `installation.md`, `how-to-use.md` (workflows plus the code-derived feature reference), `commands.md`, `api/` (`index.md`, `drugs-data.md` for exports/reload, `creator.md` for creator callbacks) and topic pages (`configuration.md`, `creator.md`, `events.md`, `items.md`, `permissions.md`, `database.md`, `troubleshooting.md`). Update the page that owns the topic; do not create duplicates.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.

## Shared contribution standards

Read [CONTRIBUTING.md](CONTRIBUTING.md) before editing. Humans and agents follow
the same Kora standards and self-contained local Lua checks. Preserve the domain
constraints above and in module guides; record policy conflicts explicitly.

Copyright © 2026 Kora Framework (new contribution guidance).
