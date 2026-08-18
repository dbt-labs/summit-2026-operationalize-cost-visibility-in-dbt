# Demo 01: cluster order items from workload

## Audience outcome

Attendees can use query history and profiles to identify a clustering candidate, apply Snowflake physical design through dbt, and explain the read-versus-write tradeoff.

## Timing and interaction

- **Current planning budget:** 20 minutes; validate during the dry run.
- **Mode:** trainer-led diagnosis and follow-along implementation.
- **Attendee artifact:** `fct_order_items` clustered by the workload-supported keys.

## Setup and prerequisites

- The opening build from Demo 00 has created `fct_order_items` in attendee schemas.
- Trainer query history includes repeated execution of all five analyses under `analyses/fct_order_items/`.
- Before/after query profiles and fallback screenshots are ready.
- The representative live query is `analyses/fct_order_items/daily_shop_sales.sql`.
- Trainer automation for clustering-candidate discovery is ready to demonstrate.

## Facilitator flow

### 1. Show the workload symptom — 4 minutes

Open query history and establish that multiple recurring consumers:

- read `fct_order_items`;
- filter by bounded `ordered_date` ranges;
- filter or group by `shop_id`; and
- scan more partitions and bytes than the selective result should require.

Use the accumulated five-query history to establish frequency. Do not run all five queries live.

### 2. Run one representative before query — 2 minutes

```text
dbt show --select path:analyses/fct_order_items/daily_shop_sales.sql
```

Open the query profile and capture:

- partitions scanned versus total;
- bytes scanned;
- elapsed time; and
- evidence of pruning.

### 3. Find and evaluate candidate keys — 5 minutes

Demonstrate the trainer's clustering-candidate automation, then validate its recommendation against human context:

- keys appear repeatedly in selective filters;
- keys exist natively on the fact;
- the date key gives useful range locality;
- the shop key narrows a common reporting slice; and
- the table and workload are large and frequent enough to repay maintenance cost.

Recommend `ordered_date`, then `shop_id`, for this workload. Emphasize that automation proposes candidates; query history and economics make the decision.

### 4. Apply the dbt configuration — 3 minutes

Have attendees update `models/marts/fct_order_items.sql` to configure a table clustered by `ordered_date` and `shop_id`.

The business SQL and public column set stay unchanged. The change is physical design only.

### 5. Build the focal model — 3 minutes

```text
dbt build --select fct_order_items --full-refresh
```

A full refresh is required to establish the new physical layout. Record the model build time and rows written; clustering can add producer-side work.

### 6. Run the same query after — 3 minutes

```text
dbt show --select path:analyses/fct_order_items/daily_shop_sales.sql
```

Compare the same filters and SQL with the before profile. Focus on partitions and bytes scanned before elapsed time, which can be noisy under workshop concurrency.

## Decision checkpoint

Ask:

> If these filters appeared once in query history, would you cluster the table?

Expected answer: probably not. Clustering needs enough table size, filter selectivity, and repeated read cost to repay write and automatic-reclustering cost.

## Validation and evidence

Required:

- the model builds and attached tests pass;
- the relation has the intended clustering keys;
- public columns are unchanged;
- the representative query returns the same result; and
- pruning or scan evidence improves under a stable workload.

Capture:

- partitions scanned/total;
- bytes scanned;
- query elapsed time;
- focal-model full-refresh time;
- rows or bytes written; and
- automatic clustering/reclustering implications.

## Cost framing

Clustering is expected to pay back primarily through repeated consumption queries, not through faster project builds. It may make the focal full refresh more expensive. Annualize the read savings using observed query frequency, then account for write and reclustering cost.

## Common failures and recovery

- **No visible pruning difference:** use the prepared profile; caching, table size, or concurrent warehouse work can hide the live effect.
- **Keys applied in the wrong order:** return to the dominant range filter and workload history.
- **Build still running:** continue with the prepared after profile and let the attendee build finish.
- **Different query text before/after:** discard the comparison and rerun the exact same analysis.

## Transition

> We just changed physical layout because many consumers read the same table in the same way. Next, we’ll apply that reuse logic to the model materialization itself.
