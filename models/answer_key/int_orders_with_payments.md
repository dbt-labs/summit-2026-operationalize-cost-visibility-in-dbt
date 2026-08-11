# int_orders_with_payments

## Symptom

Builds that depend on `int_orders_with_payments` run longer and consume more warehouse compute than they should because the model multiplies lower-grain inputs before aggregating them back to order grain.

## Root cause

The bad-state model joins `orders`, `order_items`, and `payments` at their native grains and only aggregates after the join. Since order items are at line-item grain and payments are at payment-attempt grain, the join expands the working row set for orders with multiple lines and payment attempts.

That means the model moves and aggregates more data than the final one-row-per-order output requires. The same fanout can also inflate order-level measures, but the workshop focus is the avoidable compute caused by the query shape.

## How the issue was identified

This pattern is identified by looking for:

- query profiles with a large row expansion during joins
- high bytes scanned, aggregation work, or spill relative to the final order-grain output
- a model that claims order grain while joining lower-grain inputs directly

## Optimization applied

The optimized version aggregates each lower-grain input to `order_id` before joining:

- `order_items` is rolled up to an order-level item summary
- `payments` is rolled up to an order-level payment summary
- both rollups are then joined back to `orders`

Both versions expose `source_updated_at`: the latest `ingested_at` timestamp across an order, its line items, and its payment attempts. `int_orders_with_payments` remains a table in this exercise; its optimized query shape is the upstream input to the separate `fct_orders` merge-incremental demo.


## Why this fix was the right one

The target grain of this model is one row per order. Aligning lower-grain inputs to order grain before joining minimizes rows carried through the join plan and produces a smaller, clearer aggregation workload.

The order-level `source_updated_at` is a separate operational capability. It gives downstream `fct_orders` a reliable signal for selecting only changed `order_id`s in its merge incremental build. It does not fix the fanout; the grain-aligned rollups make both the business calculations and the watermark cheaper to derive.

## How the fix was implemented

Before:

- `orders` joined directly to `order_items`
- `orders` joined directly to `payments`
- all aggregations, including the maximum ingestion watermark, ran after the combined fanout dataset was created

After:

- create `item_totals` grouped by `order_id`, including the latest item `ingested_at`
- create `payment_rollup` grouped by `order_id`, including the latest payment `ingested_at`
- join both order-grain rollups back to `orders`
- calculate `source_updated_at` from the three order-grain operational timestamps

## Expected benefit

Expected improvements from the optimized version:

- fewer rows processed during joins and aggregation
- lower bytes scanned and warehouse compute for the build
- simpler query profile and model maintenance
- a reliable order-level watermark that enables changed-key incremental processing downstream

## How to compare before and after

1. Build the active bad-state model and capture its Snowflake query profile.
2. Record elapsed time, bytes scanned, rows emitted by join operators, and spill metrics if present.
3. Build the answer-key version in `models/answer_key/intermediate/int_orders_with_payments.sql` and compare its profile to the bad-state build.
4. Confirm that both outputs remain one row per order and expose `source_updated_at`.
5. Run `training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql`; it applies 18 raw changes affecting 8 parent order IDs.
6. Use the optimized order-grain output as the upstream change signal for the separate `fct_orders` merge-incremental build, where only those changed order IDs are selected and merged.


## Prevention takeaway

When a model’s target grain is higher than one or more of its inputs, aggregate each lower-grain input to the target grain before joining. In dbt, explicit grain transitions reduce query work and create reusable order-grain outputs for downstream incremental models.
