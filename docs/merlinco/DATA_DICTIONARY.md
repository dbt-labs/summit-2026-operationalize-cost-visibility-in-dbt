# Merlin & Co. Apothecaries — data dictionary

Per-table column notes for the 12 raw source tables. See [ERD.md](ERD.md) for the schema diagram and [README](../README.md) for the source system overview.

Logical types are shown — all raw CSV columns arrive as text.

---

## abra_pos

### raw_orders (~15k / ~75k rows)

| Column | Notes |
|---|---|
| `order_id` | PK — `ORD-000001` |
| `customer_id` | FK → `raw_customers` |
| `shop_id` | FK → `raw_shops` |
| `ordered_at` | ⚠️ two timestamp formats |
| `status` | ⚠️ mixed case — completed (~93%), returned, cancelled, placed |
| `channel` | `in_store`, `courier_owl`, `marketplace` |
| `discount_copper` | order-level discount; 0 for ~90% of orders |

### raw_order_items (~51k / ~253k rows)

| Column | Notes |
|---|---|
| `order_item_id` | PK — `ITM-000001` |
| `order_id` | FK → `raw_orders`; every order has ≥1 item |
| `potion_sku` | FK → `raw_potions`; no repeated SKU within one order |
| `quantity` | 1–5, skewed to 1 |
| `unit_price_copper` | price at time of sale — drifts ±5% around base price, inflates ~8% across window |

### raw_payments (~17k / ~86k rows)

| Column | Notes |
|---|---|
| `payment_id` | PK — `PAY-000001` |
| `order_id` | FK → `raw_orders`; ~8% of orders split across two payments, ~5% have a failed attempt before success |
| `method` | `coin`, `guild_credit`, `crystal_transfer`, `barter` |
| `amount_copper` | successful payments sum to order total (items − discount) |
| `status` | `success`, `failed`, `refunded` |
| `paid_at` | ⚠️ two timestamp formats |

### raw_potions (120 rows)

| Column | Notes |
|---|---|
| `potion_sku` | PK — `POT-0001` |
| `potion_name` | e.g. *Elixir of Focused Mind* |
| `category` | ⚠️ mixed case — Healing, Clarity, Luck, Strength, Invisibility, Love |
| `base_price_copper` | list price (100 copper = 1 gold crown) |
| `potency` | 1–10 |
| `shelf_life_days` | 14–365 |
| `is_regulated` | ⚠️ messy boolean — `Y`/`N`/`yes`/`no`/`TRUE`/`FALSE` |
| `introduced_at` | ~30% of potions launch mid-window |

---

## grimoire_crm

### raw_customers (5k / 20k rows)

| Column | Notes |
|---|---|
| `customer_id` | PK — `WIZ-00001` |
| `full_name` | |
| `email` | ⚠️ ~2% null |
| `home_region` | ⚠️ inconsistent coding — conform to `raw_shops.region` in staging |
| `signed_up_at` | 2023-01 onward; orders never precede signup |
| `birth_year` | 1885–2007 |
| `favored_discipline` | ⚠️ mixed case — Healing, Divination, Alchemy, … |

### raw_guilds (12 rows)

| Column | Notes |
|---|---|
| `guild_id` | PK — `GLD-01` |
| `guild_name` | |
| `founded_year` | |

### raw_guild_memberships (~3.6k / ~14.5k rows)

SCD2 — `valid_from` / `valid_to` (null = current). ~30% of promoted members have a closed row at their prior tier. ~65% of customers belong to a guild.

| Column | Notes |
|---|---|
| `membership_id` | PK — `MEM-00001` |
| `customer_id` | FK → `raw_customers` |
| `guild_id` | FK → `raw_guilds` |
| `tier` | ⚠️ mixed case — `apprentice` / `Adept` / `ARCHMAGE` |
| `valid_from` | |
| `valid_to` | null = current row |

---

## alembic_ops

### raw_shops (15 rows)

`region` is the canonical spelling — use to conform `raw_customers.home_region` in staging.

| Column | Notes |
|---|---|
| `shop_id` | PK — `SHP-01` |
| `shop_name` | e.g. *The Gilded Alembic* |
| `city` | |
| `region` | canonical; five values: Northern Reaches, Ember Coast, Silverwood, The Marshlands, Crystal Vale |
| `opened_at` | |

### raw_suppliers (15 rows)

| Column | Notes |
|---|---|
| `supplier_id` | PK — `SUP-01` |
| `supplier_name` | |
| `region` | |
| `reliability_rating` | 1–5 |
| `contracted_since` | |

### raw_ingredients (80 rows)

| Column | Notes |
|---|---|
| `ingredient_id` | PK — `ING-001` |
| `ingredient_name` | |
| `supplier_id` | FK → `raw_suppliers` |
| `unit` | ⚠️ mixed case — gram / sprig / vial / pinch / dram / bundle |
| `unit_cost_copper` | |
| `is_hazardous` | ⚠️ messy boolean |
| `harvest_season` | |

### raw_potion_ingredients (~400 rows)

Recipe bridge — maps each potion to 2–5 ingredients. Natural key is composite (`potion_sku`, `ingredient_id`).

| Column | Notes |
|---|---|
| `potion_sku` | PK + FK → `raw_potions` |
| `ingredient_id` | PK + FK → `raw_ingredients` |
| `quantity` | |
| `unit` | ⚠️ mixed case |

### raw_brew_events (8k / 40k rows)

Batch-level production log.

| Column | Notes |
|---|---|
| `brew_id` | PK — `BRW-00001` |
| `potion_sku` | FK → `raw_potions` |
| `shop_id` | FK → `raw_shops` |
| `cauldron_id` | `CDR-01` — not a dimension table |
| `brewed_at` | ⚠️ two timestamp formats |
| `batch_size` | |
| `brew_duration_minutes` | ⚠️ ~1% null |
| `quality_check` | ⚠️ mixed case — `pass` / `fail`; ~7% fail |
| `brewer_name` | |

---

## Deliberate data quirks

Referential integrity is intact (no orphaned FKs, no duplicate PKs), but staging models have real work to do:

1. **Mixed-case categoricals** — `status`, `category`, `tier`, `unit`, `quality_check`, `favored_discipline` need `lower()` normalization
2. **Two timestamp formats** — ISO-with-Z and space-separated, in every `*_at` column
3. **Inconsistent region coding** — CRM `home_region` uses four spellings; `raw_shops.region` is canonical
4. **Messy booleans** — `is_regulated`, `is_hazardous`: `Y`/`N`/`yes`/`no`/`TRUE`/`FALSE`
5. **Copper-piece integer prices** — convert to gold crowns (`/ 100.0`) in staging
6. **Sparse nulls** — ~2% customer emails, ~1% brew durations, `valid_to` empty on current memberships
