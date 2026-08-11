# Demo data operations guide

This document is the trainer-facing playbook for the workshop data foundation.

## Purpose

Attendees build dbt models into their own schemas against trainer-managed shared source data. Trainers maintain a large Snowflake source baseline, run one small weekly source-ingestion batch, and use the following daily `fct_orders` build to demonstrate how a merge incremental avoids recomputing unchanged history.

This guide exists so the workshop is:

- reproducible
- easy to hand off to a co-trainer or substitute presenter
- explicit about the source-ingestion and dbt-build cadence

## Base dataset

The trainer-managed shared source schema contains the large baseline for the 12 raw source entities. The cost/performance exercises primarily use:

- `raw_orders`
- `raw_order_items`
- `raw_payments`
- `raw_customers`
- `raw_guild_memberships`
- `raw_brew_events`

`raw_orders`, `raw_order_items`, and `raw_payments` include `ingested_at`, the operational watermark used by the `fct_orders` incremental exercise.

## Trainer-run Snowflake script

The trainer-operated Snowflake script lives in `training_assets/snowflake_scripts/`:

- `04_weekly_orders_change_batch.sql`

Run it weekly before the daily `fct_orders` build. It assigns one `batch_ingested_at` timestamp to every changed raw record.

### `04_weekly_orders_change_batch.sql`

Purpose:

- simulates a small weekly source delivery against large order history
- supplies new and changed order inputs for the merge-incremental demo
- proves that recurring warehouse work should scale with changed order IDs instead of total history

Change mix per run:

- 4 new orders
- 7 new order items for those orders
- 3 successful payments for new orders
- 2 late refund events for historical orders
- 2 corrections to historical orders
- 18 raw-source changes affecting 8 parent `order_id`s: 4 new and 4 historical

Expected downstream behavior:

- `int_orders_with_payments` recomputes the order-grain output and exposes the shared operational change signal as `source_updated_at`
- answer-key `fct_orders` inserts the 4 new order IDs and updates the 4 changed historical order IDs through its merge incremental
- unchanged historical order IDs are not selected for the merge

The script dynamically allocates IDs for the four new orders, so each normal weekly run creates new records. It is intentionally append-oriented for the workshop and is not retry-idempotent: a duplicate execution appends another batch of four new orders. The historical corrections still receive the new batch watermark on each run.

## Recommended trainer workflow

### Before the workshop

1. Confirm the large baseline is available in the shared Snowflake raw schema.
2. Confirm the raw order, item, and payment tables have non-null `ingested_at` values.
3. Confirm the active bad-state `fct_orders` is configured as a daily full-table rebuild and the answer key is the merge-incremental implementation.
4. Rehearse `04_weekly_orders_change_batch.sql` and record the expected 8 changed parent order IDs in the batch output.

### During the `fct_orders` demo

1. Start from the current shared source state and have attendees build the bad-state `fct_orders` as a full table.
2. Capture its Snowflake query profile: bytes scanned, source rows processed, target write work, elapsed time, and warehouse credits.
3. Have attendees apply the answer-key design: `incremental_strategy='merge'`, `unique_key='order_id'`, and changed-key selection from `source_updated_at`.
4. Run the answer-key model once with `--full-refresh` to establish its target.
5. Run `training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql`.
6. Run the daily answer-key `fct_orders` build incrementally.
7. Confirm that the batch contains 18 raw changes affecting 8 parent order IDs, then compare its profile to the full rebuild. The expected result is 4 inserts and 4 updates, with unchanged history untouched.

### After the workshop

1. Record the observed before/after profile metrics and any workshop-specific notes.
2. Leave the shared source state in place for the next scheduled weekly batch; the script allocates new IDs dynamically.
3. If a rehearsal requires a pristine baseline, recreate or restore the trainer-managed raw source state outside the workshop runbook. There is no routine reset script for the append-oriented batch.

## Demo dependencies by module

### `fct_orders`

Depends on:

- large shared source baseline
- `04_weekly_orders_change_batch.sql`, run before the daily incremental build
- `int_orders_with_payments.source_updated_at` as the order-grain changed-key watermark

### `int_orders_with_payments`

Depends on:

- large shared source baseline

Note:

- the join-health demo benefits from multi-line-order and multi-payment behavior in the base data. Its primary proof is the model-build query profile; it does not require trainer-run DML during the session.

### `fct_order_items`

Depends on:

- large shared source baseline

Note:

- the pruning/clustering module uses recurring filtered workload queries against this fact.

### `dim_wizards`

Depends on:

- large shared source baseline indirectly through downstream model usage patterns

### `fct_wizard_order_behavior`

Depends on:

- large shared source baseline
- `int_potion_supply_cost` as the estimated cost-proxy input for the enriched lab version

Note:

- this lab is primarily about model architecture and refactoring; the light cost enrichment gives it a believable commercial lens without turning it into a procurement demo.

## Safety notes

- Run the weekly batch once per scheduled delivery; duplicate execution appends another set of four new orders.
- Keep the batch timestamp visible in the script output and record it with the corresponding daily build profile.
- Do not manually alter the dynamically allocated IDs between runs.
- The fixed historical correction targets are `ORD-000025000`, `ORD-000075000`, `ORD-000050000`, and `ORD-000100000`.
- For a true clean-state rehearsal, restore the shared raw source baseline through the trainer’s Snowflake environment process rather than ad hoc deletes.

## Open implementation tasks

- document the final baseline row counts once the trainer-managed source state is locked
- add the scheduled weekly-ingestion and daily-build job identifiers when orchestration is finalized
- add trainer-specific runbook notes discovered during rehearsal
