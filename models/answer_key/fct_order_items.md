# fct_order_items

## Symptom

Repeated dashboard-style queries against `fct_order_items` scan more data than they should and take longer than expected even when they filter to specific dates and shops.

## Root cause

The bad-state version of `fct_order_items` is a large line-grain fact with no physical optimization aligned to the dominant access pattern.

In this workshop, the repeated workload filters heavily on:

- `ordered_date`
- `shop_id`

Without clustering aligned to that pattern, those queries can require broader scans than necessary.

## How the issue was identified

This pattern is identified by looking for:

- repeated dashboard queries against the same large fact
- common filtering on a small set of dimensions
- query history and query profiles showing poor pruning and larger-than-expected scans

The five analysis queries in `analyses/order_items_perf__*.sql` are the workload surface used to establish that pattern in the workshop.

## Optimization applied

The optimized version adds clustering to `fct_order_items` using:

- `ordered_date`
- `shop_id`

## Why this fix was the right one

Clustering should follow observed workload, not guesswork.

For this workshop, `ordered_date` and `shop_id` are the right keys because they are:

- native columns on the fact
- common filters across the dashboard workload
- broadly reusable across multiple reporting questions

That makes them a strong candidate for improving pruning on Snowflake.

## How the fix was implemented

Before:

- `fct_order_items` is materialized as a table without clustering aligned to the repeated workload

After:

- the answer-key version adds `cluster_by=['ordered_date', 'shop_id']`
- the same business logic remains in place, but the physical layout now better matches the access pattern

## Expected benefit

Expected improvements from the optimized version:

- less data scanned for the repeated workload
- faster filtered queries
- clearer workshop evidence for pruning behavior before and after clustering

## How to run the workload

Use the five analysis files in `analyses/` as the repeated dashboard workload for this module. Execute them with `dbt show` so they run in Snowflake and generate query history/profile data for the before/after comparison.

Recommended commands:

```text
dbt show --select path:analyses/order_items_perf__daily_shop_sales.sql
dbt show --select path:analyses/order_items_perf__shop_category_mix.sql
dbt show --select path:analyses/order_items_perf__top_skus_by_shop.sql
dbt show --select path:analyses/order_items_perf__daily_regulated_sales.sql
dbt show --select path:analyses/order_items_perf__shop_customer_basket.sql
```

Recommended trainer flow:

1. Run the five workload analyses against the bad-state project.
2. Review Snowflake query history / query profile to confirm the dominant filter pattern on `ordered_date` and `shop_id`.
3. Apply the clustered answer-key version of `fct_order_items`.
4. Re-run the same five analyses.
5. Compare scan volume, pruning behavior, and runtime before and after clustering.

Notes:

- `dbt show` executes the analysis SQL in Snowflake.
- The goal is not to return a huge result set; the goal is to generate a consistent workload and inspect how Snowflake executes it.
- Keep the workload queries unchanged before and after clustering so the comparison stays clean.


## How to compare before and after

1. Run the five analysis queries in `analyses/order_items_perf__*.sql` against the bad-state project.
2. Review query history and query profile to confirm repeated filtering by date and shop.
3. Compare to the answer-key version in `models/answer_key/marts/fct_order_items.sql`.
4. Re-run the same analyses after clustering is applied.
5. Compare scan volume, pruning behavior, and runtime.

## Prevention takeaway

Physical optimization should follow usage patterns. In dbt, keep the model logic clean first, then apply warehouse-specific optimizations like clustering when repeated workloads show a clear access pattern worth tuning.
