# int_orders_with_payments

## Symptom

Queries and downstream builds that depend on `int_orders_with_payments` run longer than they should, and some order-level metrics become inflated.

## Root cause

The bad-state model joins `orders`, `order_items`, and `payments` at their native grains and only aggregates after the join. Since order items are at line-item grain and payments are at payment-attempt grain, the join creates a fanout for any order with multiple line items and multiple payment rows.

That means the model does more work than necessary and can multiply measures such as:

- line item count
- total quantity
- gross revenue
- successful payment amount

## How the issue was identified

This pattern is identified by looking for:

- query profiles that show a large row expansion during joins
- order-level totals that are unexpectedly high
- a model that claims order grain while joining lower-grain inputs directly

## Optimization applied

The optimized version aggregates each lower-grain input to `order_id` before joining:

- `order_items` is rolled up to an order-level item summary
- `payments` is rolled up to an order-level payment summary
- both rollups are then joined back to `orders`

## Why this fix was the right one

The target grain of this model is one row per order. The cleanest way to preserve that grain is to align all lower-grain inputs to order grain before joining.

This fixes both correctness and performance:

- fewer rows are processed through the join plan
- order-level measures are no longer duplicated by fanout
- the query is easier to reason about because each input is explicit about its grain

## How the fix was implemented

Before:

- `orders` joined directly to `order_items`
- `orders` joined directly to `payments`
- aggregations applied only after the combined fanout dataset was created

After:

- create `item_totals` grouped by `order_id`
- create `payment_rollup` grouped by `order_id`
- join both order-grain rollups back to `orders`

## Expected benefit

Expected improvements from the optimized version:

- less data processed during execution
- simpler query shape
- more accurate order-level metrics
- faster downstream builds that depend on this intermediate

## How to compare before and after

1. Build the bad-state model and inspect downstream facts such as `fct_orders`.
2. Compare metrics for orders that have both multiple line items and multiple payment records.
3. Review the query profile and look for row explosion in the bad-state join.
4. Compare to the answer-key version in `models/answer_key/intermediate/int_orders_with_payments.sql`.
5. Confirm that the optimized version preserves one row per order without inflating measures.

## Prevention takeaway

When a model’s target grain is higher than one or more of its inputs, aggregate each lower-grain input to the target grain before joining. In dbt terms: make grain transitions explicit in intermediate models instead of hiding them inside one large join.
