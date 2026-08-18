# Demo 04: fix the exploding order join

## Audience outcome

Attendees can diagnose a many-to-many fanout from native grains and independently restructure the model so lower-grain inputs are aggregated before joining.

## Timing and interaction

- **Current planning budget:** 20 minutes; validate during the dry run.
- **Mode:** trainer frames the symptom; attendees own the SQL fix; group debrief follows.
- **Attendee artifact:** a grain-aligned `int_orders_with_payments` that returns one row per order without carrying the item × payment fanout.

## Setup and prerequisites

- Prepared Snowflake profiles show the starter join row expansion.
- Source grain counts are available for orders, order items, and payment attempts.
- `fct_orders` was full-refreshed in Demo 03 and can validate the changed intermediate output.
- Expected order-grain metric checks and fallback SQL are ready.

## Facilitator flow

### 1. Diagnose the profile — 4 minutes

Show the join plan for `int_orders_with_payments` and identify:

- one row per order in orders;
- one row per line in order items;
- one row per payment attempt in payments; and
- multiplication when an order has multiple lines and multiple attempts.

Focus first on unnecessary rows and aggregation work. Then note the correctness risk: sums and counts can also be inflated.

### 2. State the target grain and constraints — 2 minutes

The final model must remain one row per `order_id` and preserve its public columns. Both item and payment measures must be computed at order grain before the final join.

Do not prescribe CTE names or show the answer-key SQL.

### 3. Independent fix — 8 minutes

Attendees edit `models/intermediate/int_orders_with_payments.sql`.

Expected design characteristics:

- aggregate order items by `order_id`;
- aggregate payments by `order_id`;
- include the latest item/payment ingestion timestamp in the rollups;
- join both order-grain summaries back to orders; and
- derive `source_updated_at` from order-grain timestamps.

Trainers coach with grain questions:

- What is one row in this CTE?
- Can this join still multiply rows?
- Which aggregate belongs to items versus payments?
- Does the watermark survive late events?

### 4. Execute the changed intermediate and downstream fact — 3 minutes

```text
dbt build --select int_orders_with_payments fct_orders --full-refresh
```

Selecting both models is intentional: `int_orders_with_payments` is a persisted table and must be rebuilt before `fct_orders` reads it.

### 5. Debrief and compare profiles — 3 minutes

Compare attendee approaches. Then show the trainer reference architecture without asking attendees to switch branches or build the answer-key relation.

Highlight:

- rows emitted by each join;
- aggregation placement;
- spill or bytes processed;
- final order count; and
- corrected item/payment measures.

## Decision checkpoint

Ask:

> If the final GROUP BY returns one row per order, why is the original join still expensive and unsafe?

Expected answer: the engine already materialized and aggregated the multiplied working set, and duplicated lower-grain values can inflate measures before the final row count looks correct.

## Validation and evidence

Required:

- `int_orders_with_payments` is unique at `order_id`;
- `fct_orders` builds and tests pass;
- line-item counts and revenue match item-grain expectations;
- payment measures match payment-attempt expectations;
- `source_updated_at` still captures order, item, and payment arrivals; and
- public columns are preserved.

Capture:

- rows entering and leaving each join;
- bytes scanned and elapsed time;
- spill if present;
- final row count; and
- targeted two-model build time.

## Cost and governance framing

Grain tests and relationship tests can protect important assumptions, but a final uniqueness test alone does not prove that the query avoided fanout. Missing grain-aware checks can allow both inflated metrics and recurring excess compute to survive.

Keep contracts as supporting context. The main lesson is that query shape and grain decisions directly control cost.

## Common failures and recovery

- **Only `fct_orders` was built:** rebuild both models so the persisted intermediate is refreshed.
- **Payment sums are still inflated:** inspect whether payments were aggregated before the item join.
- **Orders without items/payments disappear:** preserve the intended left-join behavior and defaults.
- **Watermark becomes null:** review null handling across the three order-grain timestamps.
- **Attendees need more time:** debrief the architecture and use prepared code/profile evidence without exposing `answer_key` during the work period.

## Transition

> Keep that rule in mind: align each input to the target grain before joining. The next ticket contains the same failure mode inside a much larger model, and you’ll decide where the responsibilities should split.
