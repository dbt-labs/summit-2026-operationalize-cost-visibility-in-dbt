# Demo 02: persist a reused wizard dimension

## Audience outcome

Attendees can choose a table over a view when repeated consumption makes recomputation more expensive than scheduled persistence.

## Timing and interaction

- **Current planning budget:** 15 minutes; validate during the dry run.
- **Mode:** short guided diagnosis and attendee config change.
- **Attendee artifact:** `dim_wizards` materialized as a table.

## Setup and prerequisites

- The opening build created `dim_wizards` as a view.
- Trainer query history includes all five analyses under `analyses/dim_wizards/`.
- The representative live query is `analyses/dim_wizards/monthly_shop_membership_sales.sql`.
- Before/after query profiles are available as fallback evidence.

## Facilitator flow

### 1. Show repeated consumption — 3 minutes

Use query history to show that multiple consumers repeatedly join to `dim_wizards`. Open a profile and trace the view expansion back through customer and current-membership enrichment.

The model logic is not unusually complex. The issue is paying for the same reusable enrichment on every read.

### 2. Run one representative before query — 2 minutes

```text
dbt show --select path:analyses/dim_wizards/monthly_shop_membership_sales.sql
```

Capture elapsed time, bytes scanned, and the expanded view work in the profile.

### 3. Make the materialization decision — 3 minutes

Ask attendees to weigh:

- consumption frequency;
- source freshness requirements;
- scheduled build cadence;
- relation size; and
- acceptable staleness.

For this slowly changing, frequently reused dimension, recommend a table.

Have attendees change the model-level materialization in `models/marts/dim_wizards.sql` from `view` to `table`. The SQL and output columns stay unchanged.

### 4. Build the focal model — 3 minutes

```text
dbt build --select dim_wizards
```

Confirm that the relation is now a table and attached tests pass.

### 5. Run the same consumer after — 2 minutes

```text
dbt show --select path:analyses/dim_wizards/monthly_shop_membership_sales.sql
```

Compare the persisted dimension read with the prior view expansion.

### 6. Debrief the tradeoff — 2 minutes

A table shifts compute into scheduled builds and storage. The optimization pays when avoided consumer recomputation exceeds that maintenance cost while freshness remains acceptable.

## Decision checkpoint

Ask:

> What would make you keep this model as a view?

Expected answers include infrequent consumption, tiny/cheap SQL, a strict real-time freshness requirement, or source behavior that makes scheduled persistence inappropriate.

## Validation and evidence

Required:

- `dim_wizards` is a table;
- grain remains one row per customer;
- public columns and values are unchanged;
- attached tests pass; and
- the representative consumer no longer expands the view logic.

Capture:

- consumer bytes scanned and elapsed time;
- view-expansion versus table-read profile shape;
- dimension build time;
- repeated query frequency; and
- table storage/refresh cadence.

## Cost framing

This change may not reduce the final full-build time. It can add producer work while removing repeated work from every consumer. Estimate ROI across the query workload, not from the model build alone.

## Common failures and recovery

- **Consumer still shows view logic:** confirm the attendee built the changed model in the schema used by `dbt show`.
- **Relation-type replacement fails:** use the targeted build retry or trainer fallback relation.
- **Live runtime is noisy:** use profile shape and prepared scan evidence.
- **Result differs:** verify that only materialization changed and the SELECT list stayed intact.

## Transition

> That was a small config change driven by reuse. Now we’ll make a more consequential materialization decision based on how data arrives and how much history gets rewritten.
