---
title: Database
sidebar_position: 11
---

# Database

Tables are created and updated on start by `kora_sql` (`ensureTables`); nothing needs importing. Missing columns are added; existing columns and rows are never changed. On a blank database the tables can appear a few seconds after start, and the loaders wait up to 60 s for them.

## `kora_drugs`

One row per step, `utf8mb3`.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | int, auto increment | Primary key |
| `step` | text, unique index | `Type:pick`, `Drug:step`, `CornerSelling:settings`, `Recipes:settings`, `Custom:settings` |
| `locations` | longtext | JSON: a list of locations, or a single object for fixed steps |
| `data` | longtext | JSON settings of the step |

Written by the creator (`INSERT` or `UPDATE` by `step`, `DELETE` on removal). When `Config.storage.exampleData` is on, the bundled rows are inserted if missing.

## `kora_drugs_deliveries`

One row per dealer delivery.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | bigint unsigned, auto increment | Primary key; used in inventory exchange ids |
| `citizenid` | varchar(50) | Owner |
| `active_citizenid` | varchar(50), nullable | Set while the delivery is active; the unique index `one_active_delivery` allows one per character |
| `status` | varchar(16) | `prepared`, `issued`, `settling`, `complete` |
| `data` | longtext | JSON snapshot: dealer, item, amount, location, deadline, rules |
| `settlement` | longtext, nullable | JSON settlement terms, written before the exchange so a retry repeats the same outcome |
| `created_at` | bigint | Unix time |
| `completed_at` | bigint, nullable | Unix time |

Index `delivery_owner` on `citizenid`. Do not delete delivery rows or inventory receipts to retry an operation.

## `dealers`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | int, auto increment | Primary key |
| `name` | varchar(50) | Unique in practice: duplicates abort dealer loading |
| `coords` | longtext, nullable | JSON `x`, `y`, `z` |
| `time` | longtext, nullable | JSON `min`, `max` hours (0 to 23) |
| `createdby` | varchar(50) | Citizen id of the creating admin |

Invalid coordinates or hours, or duplicate names, make loading fail with an assertion rather than silently dropping dealers. The table matches the stock `qb-drugs` `dealers` table, so existing rows are read as they are. Do not run both providers together.
