# Demo 03: process changed orders incrementally

## Audience outcome

Attendees can identify a strong incremental candidate from ingestion and write history, choose a Snowflake strategy that fits new and updated keys, and implement a merge incremental safely.

## Timing and interaction

- **Current planning budget:** 25 minutes; validate during the dry run.
- **Mode:** guided evidence review, 5–10 minutes of individual implementation, then strategy debrief.
- **Attendee artifact:** `fct_orders` configured as a merge incremental keyed by `order_id` with changed-row filtering.

## Setup and prerequisites

- `fct_orders` exists as a full table from the opening build.
- Prepared query history shows historical full scans and full-table writes.
- Prepared ingestion evidence shows a small changed-row ratio, new orders, corrections, and late payment/refund events.
- Before/after build screenshots and Snowflake profiles are ready.
- No live source ingestion or baseline reset is planned.

## Facilitator flow

### 1. Establish the symptom from history — 5 minutes

Show:

- target row growth over time;
- source ingestion cadence;
- the ratio of changed parent orders to full history;
- recurring bytes scanned and written by `fct_orders`; and
- examples of historical `order_id`s changing after initial creation.

Frame the question as model design from observed behavior: the target is large, changes are sparse, the grain has a stable key, and updates are not append-only.

### 2. Define the strategy requirements — 3 minutes

The strategy must:

- insert new orders;
- update existing orders affected by corrections or late events;
- preserve one row per `order_id`;
- avoid rewriting unchanged history; and
- fail safely on unexpected schema change.

`source_updated_at` is the technical signal for identifying work newer than the target high-watermark.

### 3. Individual implementation — 5–10 minutes

Attendees update `models/marts/fct_orders.sql` independently. Acceptance criteria:

- materialization is `incremental`;
- `incremental_strategy` is `merge`;
- `unique_key` is `order_id`;
- schema changes fail explicitly; and
- an `is_incremental()` branch limits recurring work using `source_updated_at` while a full refresh selects all rows.

Trainers circulate and ask questions about grain and update behavior. Do not show `models/answer_key/`.

### 4. Build the focal model — 3 minutes

After attendees converge, establish their local target with:

```text
dbt build --select fct_orders --full-refresh
```

This validates the model and creates the incremental target. It does not demonstrate recurring savings because no live source batch follows it.

### 5. Use prepared recurring-run evidence — 4 minutes

Show the saved before/after screenshots and profiles:

- full-table source and target work before;
- changed-key selection after;
- bytes scanned;
- rows merged;
- elapsed time; and
- credits where available.

The trainer-managed weekly script exists to generate this history, but it is not executed during the workshop.

### 6. Compare Snowflake strategies — 3 minutes

Use a direct recommendation:

- **Append:** fastest and simplest when rows are immutable and every incoming row is new.
- **Merge:** best fit here because sparse batches contain both inserts and updates to stable `order_id`s.
- **Delete+insert:** useful when replacing complete keys is simpler or faster than column-level matching, with more rewrite work to evaluate.
- **Microbatch:** consider for very large time-series workloads that can be processed in bounded event-time batches.

No strategy is universally fastest. Choose from source mutability, batch size, target grain, scan pattern, and correctness requirements. For this workload, merge is the clear default.

## Decision checkpoint

Ask:

> Why is append unsafe even if most weekly records are new?

Expected answer: corrections and late payment/refund events change existing order-level outputs, so append would duplicate keys or leave stale rows.

## Validation and evidence

Required:

- full refresh succeeds and attached tests pass;
- `order_id` remains unique and non-null;
- public columns remain stable;
- the incremental branch references a reliable order-grain watermark; and
- prepared recurring-run evidence shows less unchanged history rewritten.

Capture or present:

- full-refresh build time;
- prepared recurring incremental build time;
- source/target bytes scanned;
- rows merged;
- changed-row ratio; and
- execution frequency for annualization.

## Cost framing

Separate initial and recurring cost. Incremental models still need an initial full refresh and occasional recovery refreshes. Savings come from routine runs processing a small change set instead of full history.

Use prepared screenshots for the before/after timing so workshop concurrency does not distort the comparison.

## Common failures and recovery

- **`unique_key` missing:** explain that merge cannot reliably match target rows without the grain key.
- **Filter runs during full refresh:** check the `is_incremental()` guard.
- **Target watermark can be null:** use a safe initial fallback in the target aggregate.
- **Model builds but recurring branch is unproven:** use the prepared run evidence; do not invent live source changes.
- **Schema mismatch from an earlier attempt:** full-refresh only the focal model.

## Transition

> We reduced recurring writes by matching model strategy to data arrival. Next we’ll look upstream at a query that does far too much work before it ever reaches order grain.
