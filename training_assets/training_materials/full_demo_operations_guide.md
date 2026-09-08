# Demo data operations guide

This is the trainer-facing playbook for the workshop data foundation, attendee build flow, and prepared performance evidence.

## Operating model

Attendees build dbt models into their own schemas against trainer-managed shared Snowflake source data. They workshop changes directly in the starter models and do not inspect or build `models/answer_key/` during the live exercises.

The attendee full-build command is:

```text
dbt build --exclude tag:optimized
```

Attendees run exactly two full builds:

1. at the beginning of Demo 00 to establish all development relations; and
2. at the end of Demo 06 to compare the final project runtime with the opening baseline.

Between those points, use targeted builds or focal-model full refreshes only. Start the opening build as early as possible so it runs while trainers introduce the project and evidence framework.

Trainer-only benchmark DAGs remain available:

```text
dbt build --select +tag:unoptimized
dbt build --select +tag:optimized
```

Run them sequentially when they share a target schema because their staging and supporting dependencies overlap.

## Base dataset

The trainer-managed shared raw schema contains the large baseline for all 12 source entities. The performance exercises primarily use:

- `raw_orders`;
- `raw_order_items`;
- `raw_payments`;
- `raw_customers`;
- `raw_guild_memberships`; and
- `raw_brew_events`.

`raw_orders`, `raw_order_items`, and `raw_payments` include `ingested_at`, the operational signal used to establish historical arrival cadence and changed-key behavior for the incremental exercise.

The smaller CSV baseline under `seeds/large_data/` exists for portable setup and reset. Attendees do not reseed shared raw data during the live workshop.

## Weekly source batch: trainer evidence generation only

The script is:

- `training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql`.

It creates a realistic mixture of new and changed order activity with one `batch_ingested_at` timestamp:

- 4 new orders;
- 7 order items for those orders;
- 3 successful payments for new orders;
- 2 late refund events for historical orders;
- 2 corrections to existing orders; and
- 18 raw changes affecting 8 parent `order_id`s: 4 new and 4 historical.

The script is used before the workshop to accumulate ingestion and model-query history that demonstrates:

- a large historical target with a small changed-row ratio;
- repeated full scans and unnecessary bytes written by the table materialization;
- late changes to existing order keys; and
- why a merge incremental keyed by `order_id` fits the observed arrival pattern.

Do not run this script live. The incremental module uses prepared query history, profiles, and build screenshots. No live baseline reset or attendee ingestion step is required.

The script dynamically allocates IDs for new records. Each normal execution creates a new batch. It is intentionally append-oriented and is not a replay-idempotent production ingestion process.

## Trainer preflight

1. Confirm the large baseline exists in `APOTHECARIES.RAW`.
2. Confirm raw primary keys are unique and order-item/payment foreign keys resolve to `raw_orders`.
3. Confirm `ingested_at` is populated on raw orders, order items, and payments.
4. Run `dbt parse --no-partial-parse`.
5. Confirm the attendee exclusion returns no answer-key nodes:

```text
dbt ls --select path:models/answer_key --exclude tag:optimized
```

6. Confirm the trainer benchmark selectors:

```text
dbt ls --select tag:unoptimized --resource-type model --output name
dbt ls --select tag:optimized --resource-type model --output name
```

7. Build both trainer benchmark DAGs sequentially and confirm tests pass.
8. Rehearse the attendee opening and closing command in a clean developer schema.
9. Capture prepared evidence for each module and verify that screenshots show the warehouse, query, relation, and timing context.
10. Confirm the live dbt State job and all pre-run job examples are available in the workshop account.

## Attendee build schedule

### Opening full build

Run during Demo 00:

```text
dbt build --exclude tag:optimized
```

Record the total runtime. Continue project orientation while the command runs.

### Targeted model work

Use the narrowest selector that executes the changed SQL and its tests:

- clustering: full-refresh `fct_order_items` after adding `cluster_by`;
- dimension persistence: build `dim_wizards` after changing the materialization;
- incremental orders: full-refresh `fct_orders` after implementing the incremental configuration, then use prepared screenshots for recurring-run evidence;
- exploding join: full-refresh `fct_orders` so the changed `int_orders_with_payments` SQL executes in its downstream model; and
- customer behavior refactor: full-refresh `fct_wizard_order_behavior` after creating the focused intermediates and thin mart.

Exact commands belong in the corresponding facilitator outlines. Trainers should pace these targeted builds across the room and use fallback screenshots if warehouse concurrency makes live timings noisy.

### Closing full build

Run at the end of Demo 06:

```text
dbt build --exclude tag:optimized
```

Compare with the opening runtime, then pair that result with model-level and consumption-query evidence. The current trainer benchmark improved from 3:13 to 2:46: 27 seconds, or 14.0%. A linear 30-minute illustration becomes approximately 25:48, but trainers should avoid treating that scale-up as a precise credit forecast.

## Workload history and live queries

Ten analysis queries exist to create representative history:

- five under `analyses/fct_order_items/`; and
- five under `analyses/dim_wizards/`.

Trainers may automate all ten before the workshop to establish stable query history. During the workshop, run only:

- one representative `fct_order_items` query before and after clustering; and
- one representative `dim_wizards` consumer query before and after persistence.

Keep each before/after SQL statement and filter set stable. Use the accumulated history to explain frequency and candidate selection without making 40+ attendees wait for ten live queries.

## Dependencies by module

### Clustering and pruning

- Focal model: `fct_order_items`.
- Uses repeated history from `analyses/fct_order_items/`.
- Requires a focal-model full refresh to apply clustering.
- Compare partitions scanned, bytes scanned, pruning, elapsed time, and write/reclustering tradeoffs.

### Dimension materialization

- Focal model: `dim_wizards`.
- Uses repeated history from `analyses/dim_wizards/`.
- Compare one representative consumer query before and after persistence.

### Incremental orders

- Focal model: `fct_orders`.
- Uses prepared historical ingestion and build evidence.
- Requires no live source DML.
- Discuss `merge`, target grain, `unique_key`, late updates, and recurring versus initial full-refresh cost.

### Join health

- Edited model: `int_orders_with_payments`.
- Executed through the downstream `fct_orders` build.
- Requires multi-line orders and multiple payment attempts in the base data.
- Refer back to the target-grain concept during the refactor module.

### Modular customer behavior

- Focal model: `fct_wizard_order_behavior`.
- Expected design uses focused customer-grain rollups before final assembly.
- Uses `int_potion_supply_cost` as the estimated cost-proxy input.
- Compare targeted build time, rows through joins, query shape, and annualized execution cost.

## Safety and recovery

- Run the weekly batch only as part of planned trainer evidence generation.
- Keep its timestamp and affected IDs with the corresponding evidence.
- Do not manually alter dynamically allocated IDs.
- Restore a pristine raw baseline through the trainer's Snowflake environment process rather than ad hoc deletes.
- Keep prepared screenshots or saved query profiles for every warehouse-dependent comparison.
- If an attendee's opening build is still running when Demo 01 starts, pair them with a completed schema or use trainer relations for profile review while the build finishes.

## Remaining environment-specific tasks

- Record final shared-baseline row counts after the workshop account is provisioned.
- Add final job and environment identifiers.
- Record warehouse size, thread count, auto-suspend, and cache assumptions used for benchmark captures.
- Automate the ten analysis queries used to accumulate workload history.
- Capture stable opening/closing build evidence and targeted-model fallback screenshots.
