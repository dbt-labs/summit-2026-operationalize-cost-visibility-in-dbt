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

The five analysis queries under `analyses/fct_order_items/` are the workload surface used to establish that pattern in the workshop.

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

The five analysis files under `analyses/fct_order_items/` create the repeated dashboard workload used to establish query history and clustering candidates. Trainers should automate all five before the workshop so frequency and filter patterns are visible.

During the live module, run only one representative query before and after:

```text
dbt show --select path:analyses/fct_order_items/daily_shop_sales.sql
```

Recommended trainer flow:

1. Use prepared history from all five analyses to establish repeated filtering on `ordered_date` and `shop_id`.
2. Run `daily_shop_sales.sql` once against the attendee's unclustered relation.
3. Review its Snowflake profile and the trainer's clustering-candidate automation.
4. Apply clustering to the starter `fct_order_items` model and full-refresh that focal model.
5. Run the exact same representative query again.
6. Compare partitions scanned, bytes scanned, pruning, elapsed time, and write/reclustering cost.

Notes:

- `dbt show` executes the analysis SQL in Snowflake.
- The other analyses exist to build stable workload history, not to consume live workshop time.
- Keep the representative SQL and filters unchanged before and after.
- Clustering can add producer and reclustering cost; include that in the payback calculation.

## How to compare before and after

1. Review the accumulated five-query workload history against the starter relation.
2. Run one representative query live before and after the focal-model full refresh.
3. Compare scan volume, pruning behavior, runtime, and clustering maintenance cost.
4. After the workshop, compare the implementation with `models/answer_key/marts/fct_order_items__optimized.sql`.


## Prevention takeaway

Physical optimization should follow usage patterns. In dbt, keep the model logic clean first, then apply warehouse-specific optimizations like clustering when repeated workloads show a clear access pattern worth tuning.
