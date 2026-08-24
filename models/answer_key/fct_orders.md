# fct_orders

## Demo synopsis

`fct_orders` has millions of historical rows, but routine source deliveries change only a small set of records. Historical job and query evidence shows the current table materialization repeatedly scanning and rewriting full history, so warehouse work is driven by total table size rather than actual change volume.

The workshop asks attendees to inspect that evidence and choose an incremental strategy that fits the observed behavior: a merge incremental keyed on `order_id`, with exact changed-key selection from an operational watermark.

### Evidence prepared before the workshop

Trainer-managed evidence is generated with three sequential source batches:

- `training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql`
- `training_assets/snowflake_scripts/05_weekly_orders_change_batch_2.sql`
- `training_assets/snowflake_scripts/06_weekly_orders_change_batch_3.sql`

Each batch contains 18 raw mutations and affects exactly eight parent `order_id`s:

- 4 new orders with 7 order items and 3 successful payments;
- 2 historical corrections at the order or item grain;
- 2 late payment events for other historical orders; and
- one shared, monotonic `batch_ingested_at` watermark.

Across the three batches, the workload includes order corrections, item corrections, late successful payments, failed attempts, and refunds. This demonstrates that merge must both insert new grain keys and update historical keys when any contributing source record changes.

The scripts record inserted keys and preserve before-images in small control tables. `training_assets/snowflake_scripts/07_reset_fct_orders_workshop.sql` consumes that metadata once, after all evidence collection, to restore the raw baseline between workshop sessions.

Prepared before/after profiles demonstrate that the merge incremental inserts new keys, updates changed historical keys, and excludes unchanged history. During the workshop, attendees spend 5–10 minutes implementing the incremental configuration and changed-key selector, then run a targeted `--full-refresh` to establish and validate their local target. Trainers use prepared screenshots for recurring incremental timing and write evidence. No source ingestion or baseline reset runs live.

## Symptom

Builds of `fct_orders` take longer and consume more compute than they should because the model rebuilds the full order history even when only a small share of source records changed.

## Root cause

The starter version is materialized as a full `table`. Every run recomputes and rewrites all historical orders, so cost grows with total history rather than the changed-row ratio.

At scale, this creates unnecessary scans, aggregation work, and target-table churn.

## How the issue was identified

Look for:

- a fact table that grows over time;
- repeated full rebuilds of mostly unchanged history;
- a low ratio of changed source records to total target rows;
- late events or corrections that update existing grain keys; and
- model cost that scales with full history rather than each delivery.

## Optimization applied

The optimized version is a merge incremental model:

- `unique_key='order_id'` matches incoming order rows to the target;
- `incremental_strategy='merge'` inserts new orders and updates changed orders;
- `source_updated_at` captures the latest raw ingestion timestamp across each order, its items, and its payments; and
- only order IDs newer than the target high-watermark are selected for recurring work.

## Why this fix was the right one

`fct_orders` is a strong incremental candidate:

- it is a large, growing fact;
- routine source activity is small relative to history;
- the target grain has a stable key; and
- late item, payment, refund, and order corrections can change existing outputs.

Append is unsafe because historical keys can change. Merge handles both inserts and updates without rebuilding unchanged history. `order_id` is the correct merge key because the target grain is one row per order.

## How the fix was implemented

Before:

- `fct_orders` is materialized as `table`;
- every run rebuilds and rewrites full history; and
- cost grows with total history.

After:

- `fct_orders` is materialized as `incremental`;
- the model uses `incremental_strategy='merge'` and `unique_key='order_id'`;
- the upstream order-grain model surfaces `source_updated_at`;
- an `is_incremental()` branch selects changed order IDs; and
- the target persists the technical high-watermark.

## Expected benefit

- materially less recurring data processing;
- fewer target rows written or merged;
- shorter routine model runtime;
- lower repeated warehouse cost; and
- late updates included without a broad time-based lookback.

## Trainer evidence collection workflow

1. Start from a clean raw baseline. Do not run the reset between batches.
2. Establish both targets before the first batch:

   ```shell
   dbt build --select +fct_orders --full-refresh
   dbt build --select +fct_orders__optimized --full-refresh
   ```

3. Run batch 1, then build the table and optimized paths separately:

   ```shell
   dbt build --select +fct_orders
   dbt build --select +fct_orders__optimized
   ```

4. Capture model-level elapsed time, bytes scanned, rows written or merged, and credits.
5. Repeat steps 3–4 with batch 2 and then batch 3.
6. Confirm each optimized recurring run processes four new and four historical `order_id`s while the table version continues to process full history.
7. After all profiles are captured, run `07_reset_fct_orders_workshop.sql`.
8. Full-refresh both paths again. The reset hard-deletes inserted source rows, and the current merge model does not propagate source deletes:

   ```shell
   dbt build --select +fct_orders --full-refresh
   dbt build --select +fct_orders__optimized --full-refresh
   ```

The three batch timestamps must increase between runs because the optimized selector uses `source_updated_at > max(source_updated_at)` from the target. Running each script in sequence naturally supplies a new `current_timestamp()` watermark.

## Workshop comparison workflow

1. Review prepared historical ingestion cadence and full-table write evidence.
2. Inspect the starter model's materialization and target grain.
3. Implement merge incremental configuration and changed-key filtering in the starter model.
4. Run `dbt build --select fct_orders --full-refresh` to establish and validate the attendee target.
5. Use prepared recurring-run screenshots and profiles to compare bytes scanned, rows merged, elapsed time, and credits.
6. Discuss Snowflake append, merge, delete+insert, hard-delete handling, and microbatch tradeoffs.
7. Annualize the observed recurring savings using stated run-frequency assumptions.

After the workshop, compare the implementation with `models/answer_key/marts/fct_orders__optimized.sql`.

## Prevention takeaway

Large historical facts should not default to full-table rebuilds. When grain has a stable key and source changes can be identified reliably, choose an incremental strategy from actual arrival and update behavior. Review changed-row ratio and target write volume during model design, not only after warehouse cost grows.
