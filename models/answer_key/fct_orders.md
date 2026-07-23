# fct_orders

## Symptom

Builds of `fct_orders` take longer and consume more compute than they should because the model rebuilds the full order history every time it runs.

## Root cause

The bad-state version is materialized as a full `table`. That means each run recomputes all historical orders even though the source data arrives over time and most existing rows are unchanged.

In a warehouse with growing order history, this creates unnecessary work on every run.

## How the issue was identified

This pattern is identified by looking for:

- fact tables that grow over time
- repeated full rebuilds of mostly unchanged history
- model runs where the cost scales linearly with table size instead of with new or changed data volume

## Optimization applied

The optimized version converts `fct_orders` to an incremental model and then refines the incremental filter logic.

This workshop intentionally teaches that in two phases:

### Phase 1: initial incremental optimization

The first step is to stop rebuilding the full table and process only a bounded recent slice of order history.

A simple phase-1 implementation looks like this:

```sql
{% if is_incremental() %}
    where ordered_at >= (
        select coalesce(dateadd(day, -3, max(ordered_at)), '1900-01-01'::timestamp_ntz)
        from {{ this }}
    )
{% endif %}
```

This is a strong first improvement because it materially reduces the amount of data processed on routine runs.

### Phase 2: refine the incremental filter for late-arriving changes

Once late-arriving payment/refund activity is introduced, filtering only on recent `ordered_at` values is no longer enough. Older orders can have new payment events that change:

- `amount_paid_gold`
- `is_split_payment`
- `had_failed_attempt`
- `is_refunded`

The final answer-key implementation handles this by identifying changed `order_id` values from the upstream intermediate and rebuilding only those orders.

## Why this fix was the right one

`fct_orders` is a classic incremental candidate:

- it is fact-like
- it grows over time
- routine runs typically add a small amount of new or recently changed data relative to the full table size

Phase 1 reduces unnecessary processing immediately.

Phase 2 keeps that performance benefit while improving correctness for changed historical orders.

## How the fix was implemented

Before:

- `fct_orders` is materialized as `table`
- every run rebuilds the entire model

Phase 1:

- `fct_orders` is materialized as `incremental`
- `unique_key='order_id'` is used
- a simple recent-time filter on `ordered_at` limits processing to a small recent window

Phase 2:

- the model still uses `incremental` with `unique_key='order_id'`
- the incremental filter is refined to identify changed `order_id` values from `int_orders_with_payments`
- changed historical orders are rebuilt when new payment activity updates order-level business state

## Expected benefit

Expected improvements from the optimized version:

- less data processed on routine runs
- shorter model runtime
- lower warehouse cost for repeated builds
- better correctness for late-arriving payment/refund events
- less unnecessary churn than broad full-history rebuilds

## How to compare before and after

1. Build the bad-state version of `fct_orders` from the main DAG.
2. Review the model runtime and warehouse profile.
3. Compare to the final answer-key version in `models/answer_key/marts/fct_orders.sql`.
4. Run `training_assets/snowflake_scripts/01_append_orders_batch.sql` and rerun the model to demonstrate phase 1 behavior.
5. Run `training_assets/snowflake_scripts/02_late_payment_updates.sql` and show why the phase-1 filter is no longer sufficient.
6. Compare the final answer-key logic, which rebuilds changed order IDs instead of relying only on recent `ordered_at` values.

## Prevention takeaway

Large historical facts should not default to full-table rebuilds. In dbt, use incremental materialization when the model grows over time and routine runs usually touch only a small share of total history. Then review the incremental predicate itself to make sure it captures both performance and correctness requirements as the source data evolves.
