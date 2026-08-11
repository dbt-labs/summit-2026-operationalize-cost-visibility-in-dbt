# fct_orders

## Demo synopsis

`fct_orders` has millions of historical rows, but a typical weekly source delivery changes only a small set of records. The current daily job rebuilds all history, so warehouse work is driven by total table size rather than actual change volume.

The workshop asks attendees to inspect the model’s build pattern and choose an incremental strategy that fits it: a merge incremental keyed on `order_id`, with exact changed-key selection from an operational watermark.

### Set-up for this demo

1. The daily before job rebuilds the full table.
2. A weekly source batch runs from `training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql`.
   - 18 raw records are inserted or updated.
   - 4 new orders, 7 order items, and 3 new payments are appended.
   - 2 existing orders are corrected.
   - 2 late refund events are added for older orders.
   - all affected rows share one `batch_ingested_at` value.
3. The batch affects 8 parent `order_id`s: 4 new and 4 historical.
4. The daily after job uses a merge incremental.
   - new `order_id`s are inserted
   - changed existing `order_id`s are updated
   - unchanged history is untouched

In the demo, compare the build query profile before and after:

- bytes scanned
- source rows processed
- target rows merged
- elapsed time
- warehouse credits
- write and merge work

Have attendees map symptom → diagnosis → optimization, spend a few minutes applying the incremental configuration and changed-key selector, run an initial `--full-refresh`, then run the weekly ingestion batch and rebuild. The answer key provides a stable before/after comparison for projected annual cost and savings.

This demonstrates both:

- table → incremental materialization
- avoided write churn through exact changed-key selection

## Symptom

Builds of `fct_orders` take longer and consume more compute than they should because the model rebuilds the full order history every day even when only a few source records changed.

## Root cause

The bad-state version is materialized as a full `table`. Every run recomputes and rewrites all historical orders, even though the weekly source delivery affects only a handful of parent `order_id`s.

At scale, this creates unnecessary scans, aggregation work, and target-table churn on every daily run.

## How the issue was identified

This pattern is identified by looking for:

- a fact table that grows over time
- repeated full rebuilds of mostly unchanged history
- a low ratio of changed source records to total target rows
- model cost that scales with full history rather than the weekly change volume

## Optimization applied

The optimized version is a merge incremental model:

- `unique_key='order_id'` matches incoming order rows to the existing target
- `incremental_strategy='merge'` inserts new orders and updates changed orders
- `source_updated_at` identifies the latest raw-record ingestion timestamp across each order, its items, and its payments
- only order IDs with a `source_updated_at` later than the target high-watermark are recomputed and merged

## Why this fix was the right one

`fct_orders` is a classic incremental candidate:

- it is a large, fact-like table
- it grows over time
- routine source activity is small relative to total history
- late payment and refund events can change existing order-level outputs

A merge incremental handles both new orders and updates to existing orders without reprocessing unchanged history. `order_id` is the correct merge key because the target grain is one row per order.

## How the fix was implemented

Before:

- `fct_orders` is materialized as `table`
- every daily run rebuilds and rewrites the complete order history
- the build cost grows with total history

After:

- `fct_orders` is materialized as `incremental`
- the model uses `incremental_strategy='merge'` and `unique_key='order_id'`
- `int_orders_with_payments` surfaces `source_updated_at` at order grain
- the incremental selector rebuilds only changed order IDs
- the target persists `source_updated_at` as its technical high-watermark

## Expected benefit

Expected improvements from the optimized version:

- materially less data processed on routine daily runs
- fewer target rows written or merged
- shorter model runtime
- lower warehouse cost for repeated builds
- late payment/refund changes included without widening a time-based lookback window

## How to compare before and after

1. Run the daily before job and capture its Snowflake query profile.
2. Record runtime, bytes scanned, source rows processed, target write work, and warehouse credits.
3. Build the answer-key model once with `--full-refresh` to establish its target.
4. Run `training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql`.
5. Run the answer-key model incrementally and confirm that it processes and merges only the 8 changed parent order IDs.
6. Compare the before and after profiles and annualize the observed daily cost difference.

## Prevention takeaway

Large historical facts should not default to full-table rebuilds. When the model’s grain has a stable key and source changes can be identified reliably, use a merge incremental model that rebuilds only changed keys. Review the source arrival pattern and target write volume as part of model design, not only after warehouse cost grows.
