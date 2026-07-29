# Demo data operations guide

This document is the trainer-facing playbook for the workshop data foundation.

## Purpose

Attendees build dbt models into their own schemas against trainer-managed shared source data. Trainers control the workshop state by loading a stable large base dataset and then applying a small set of Snowflake DML scripts to simulate new source events.

This guide exists so the workshop is:

- reproducible
- easy to reset between sessions
- transferable to a co-trainer or substitute presenter

## Base dataset

The stable source-data baseline lives in:

- `seeds/large_data/abra_pos/raw_orders.csv`
- `seeds/large_data/abra_pos/raw_order_items.csv`
- `seeds/large_data/abra_pos/raw_payments.csv`

These are the active training seeds and should remain the starting point for workshop sessions.

## Trainer-run Snowflake scripts

The trainer-operated Snowflake scripts live in:

- `training_assets/snowflake_scripts/`

Current scripts:

1. `01_append_orders_batch.sql`
2. `02_late_payment_updates.sql`
3. `03_reset_demo_state.sql`

## What each script does

### `01_append_orders_batch.sql`

Purpose:

- inserts brand-new orders, matching order items, and matching payments
- supports the clean append-only incremental demo

Use this when:

- attendees have already built the base models
- you want to demonstrate the difference between a full rebuild and a clean incremental pickup

Expected attendee action after trainer runs it:

- rebuild `fct_orders` and any other relevant downstream models in their own schemas

### `02_late_payment_updates.sql`

Purpose:

- inserts late-arriving payment/refund-related events tied to existing order IDs
- supports the lesson that naive incremental logic may miss changed historical business state or may rewrite too much data

Use this when:

- attendees have already seen the append-only incremental story
- you want to demonstrate churn, correctness risk, or improved change-detection logic

Expected attendee action after trainer runs it:

- rebuild `fct_orders` and compare results under naive vs improved incremental logic

### `03_reset_demo_state.sql`

Purpose:

- removes trainer-added demo rows
- restores the shared source tables to the expected baseline between sessions

Use this when:

- ending a session
- starting a fresh rehearsal
- preparing the environment for the next training cohort

## Recommended trainer workflow

### Before the workshop

1. Confirm the base large dataset has been seeded into the shared source schema.
2. Confirm the raw source tables match expected baseline row counts.
3. Confirm the three Snowflake scripts are up to date with the current training data design.
4. Dry-run the append script, late-update script, and reset script in a non-live session.

### During the incremental demo

1. Start from the baseline shared source data.
2. Have attendees build the relevant models.
3. Run `01_append_orders_batch.sql`.
4. Have attendees rebuild and observe the clean incremental behavior.
5. Run `02_late_payment_updates.sql`.
6. Have attendees rebuild and observe the limits of naive incremental logic.
7. Apply the improved incremental logic and rebuild again.

### After the workshop

1. Run `03_reset_demo_state.sql`.
2. Reconfirm the baseline row counts in the shared source tables.
3. Note any script changes needed before the next session.

## Demo dependencies by module

### `fct_orders`

Depends on:

- base large dataset
- `01_append_orders_batch.sql`
- `02_late_payment_updates.sql`
- `03_reset_demo_state.sql`

### `int_orders_with_payments`

Depends on:

- base large dataset

Note:

- the join-health demo benefits from the richer base data, especially split-payment and multi-line-order behavior, but does not require trainer-run DML during the session.

### `fct_order_items`

Depends on:

- base large dataset

Note:

- the pruning/clustering module may later add a repeated query workload or dashboard-like surfaces, but the source-data dependency is the large base dataset itself.

### `dim_wizards`

Depends on:

- base large dataset indirectly through downstream model usage patterns

### `fct_wizard_order_behavior`

Depends on:

- base large dataset
- `int_potion_supply_cost` as the estimated cost-proxy input for the enriched lab version

Note:

- this lab is primarily about model architecture and refactoring, and the light cost enrichment gives the exercise a more believable commercial lens without changing it into a separate procurement demo.


## Safety notes

- Keep trainer-run DML tightly scoped and repeatable.
- Prefer inserting new source events over mutating old raw records in place.
- Keep reset logic keyed to explicit demo record IDs or another deterministic marker.
- Update `03_reset_demo_state.sql` whenever the demo insert scripts change.

## Open implementation tasks

- fill in concrete INSERT statements for `01_append_orders_batch.sql`
- fill in concrete INSERT statements for `02_late_payment_updates.sql`
- fill in concrete DELETE statements for `03_reset_demo_state.sql`
- document expected baseline row counts once the final seeded state is locked
- add any trainer-specific runbook notes discovered during rehearsal
