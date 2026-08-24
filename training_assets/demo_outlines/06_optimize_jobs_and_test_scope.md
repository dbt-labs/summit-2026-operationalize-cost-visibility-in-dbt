# Demo 06: optimize jobs and test scope

## Audience outcome

Attendees can distinguish dbt State, state-based selection, deferral, and model reuse; recognize unnecessary job/test work; and interpret the workshop's full-build and annualized cost evidence.

## Timing and interaction

- **Current planning budget:** 20 minutes; validate during the dry run.
- **Mode:** follow-along platform demo and workshop wrap-up.
- **Live operations:** one dbt State/model-reuse job and the attendee closing full build.
- **Prepared operations:** CI, benchmark, test-scope, cleanup, and no-State comparison runs.

## Setup and prerequisites

- The workshop account has matching State-disabled and State-enabled jobs for one graph; both use the same Git SHA, environment, warehouse, threads, and selector.
- The State-enabled job has been run at least twice. Its first run establishes State metadata; its second unchanged run is the fallback reuse evidence.
- Staging views use explicit column lists. Views containing `select *` anywhere are rebuilt by State and weaken the demo.
- The project config sets `lag_tolerance: "0s"`, so the three scripted batch ingestions invalidate affected nodes immediately.
- A successful fallback run is available if the live job queues or fails.
- Prepared before/after CI, benchmark, and test-scope runs are open in browser tabs.
- Attendees have their opening full-build runtime from Demo 00.

## Facilitator flow

### 1. Trigger the State/model-reuse job — 1 minute

Trigger the already-primed job once, before applying another source batch. Use the selector matching the prepared graph:

```text
# Starter graph
dbt build --exclude tag:optimized

# Optimized graph
dbt build --exclude tag:unoptimized
```

Do not switch graph selectors between the State-disabled and State-enabled comparison runs. Do not trigger the benchmark, CI, or test-scope jobs live.

### 2. Explain dbt State while the job runs — 7 minutes

Cover these distinctions explicitly:

- **Managed dbt State:** compares rendered logic, relevant config, relation availability, and upstream freshness to choose reuse, clone, or a normal build.
- **First versus second State run:** the first run captures a baseline; the next unchanged run demonstrates reuse.
- **State selector:** expressions such as `state:modified+` control which nodes enter a command and are separate from managed State reuse.
- **Deferral:** eligible `ref()` calls resolve to existing relations in another environment.
- **Model reuse:** selected unchanged work can be skipped or cloned instead of recomputed.
- **Incremental compilation:** the initial full-load branch and later `is_incremental()` branch produce different rendered SQL, so the transition run correctly rebuilds.

Explain the workshop State config in plain English:

- `lag_tolerance: "0s"` means an upstream change is eligible to rebuild immediately. The default `45m` is a debounce window after a change, which would make the live ingestion batches appear unchanged if the job runs right away.
- `require_fresh_data_from: any` means one changed direct parent is enough; keep it so order corrections, item corrections, and late payments each propagate.
- `evaluate_volatile_sql: false` treats `current_date` and similar expressions as stable for reuse. Turn it on only where a changing runtime value must refresh the business result.
- `pre_clone: if_missing` mainly protects incrementals and snapshots in fresh dev/CI schemas.
- `execute_hooks_on_any_reuse: false` avoids running hooks when the model itself is reused.

Use the order lineage as the example. The raw data is static except for:

- `04_weekly_orders_change_batch.sql`
- `05_weekly_orders_change_batch_2.sql`
- `06_weekly_orders_change_batch_3.sql`

After one batch, the next State run should rebuild the three affected Abra POS staging views and their affected descendants while reusing unrelated branches. A subsequent run without another batch should return to reuse.

### 3. Show prepared job evidence — 5 minutes

Walk through saved runs rather than waiting for execution:

- State-disabled repeated run;
- first State-enabled baseline run;
- second State-enabled unchanged/reuse run;
- post-ingestion changed-data run;
- CI `state:modified+` before;
- cautious indirect test selection after;
- explicit modified-incremental validation;
- PR-schema cleanup; and
- selected test counts.

Connect gaps in test and state configuration to cost: broad selection repeats expensive work, while overly narrow selection can miss the assumptions that keep incremental and join behavior safe.

### 4. Review the live State result — 2 minutes

Compare the live run with both the State-disabled run and the first State-enabled baseline:

- selected, built, and reused work;
- runtime;
- credits or warehouse time;
- staging-view eligibility; and
- any nodes that correctly rebuilt because of source changes or incremental SQL changes.

If the job is still queued or running, switch to the saved second State-enabled run and keep the workshop moving.


### 5. Start the closing full build — 1 minute

Have attendees run:

```text
dbt build --exclude tag:optimized
```

This is the second and final full build of the workshop.

### 6. Wrap the cost story while builds run — current 4-minute planning budget

Use `training_assets/demo_outlines/07_conclusion_notes.md` as the source for the wrap-up slides and speaker notes.

Cover only the conclusions that fit the rehearsed time:

- the observed 3:13 → 2:46 whole-build comparison;
- the 27-second / 14.0% reduction;
- why the scaled 30-minute example is illustrative rather than predictive;
- why clustering and persistence pay back primarily through repeated consumption;
- why incremental savings appear on recurring runs; and
- why shared upstream models and tests dilute the whole-project percentage.

Ask attendees to record their closing time when the build finishes and compare it with their own opening baseline. If the dry run shows this segment is too long, keep the observed benchmark and the multi-surface ROI takeaway, then move the detailed optimization-by-optimization interpretation to take-home material.


## Decision checkpoint

Ask:

> When should a job use `state:modified+`, and when should it still run a broader scheduled validation?

Expected answer: state-scoped CI gives fast feedback on changed resources and affected descendants; broader deploy or scheduled jobs still provide complete quality coverage, source freshness, and protection against assumptions outside the code diff.

## Validation and evidence

Required:

- the live or fallback State job has a known comparison artifact and defer target;
- before/after job settings are documented;
- attendee closing builds exclude `tag:optimized`;
- opening and closing runtimes use comparable targets and warehouse settings; and
- annualized claims state frequency and cost assumptions.

Present:

- selected/reused node counts;
- test counts;
- job runtimes and credits;
- cleanup behavior;
- attendee opening/closing build times; and
- focal-model and consumption-query evidence from Demos 01–05.

## Common failures and recovery

- **Live job queues:** use the saved successful run immediately.
- **State job rebuilds everything:** inspect comparison artifact, code revision, environment config, and reuse eligibility.
- **Deferral resolves unexpectedly:** verify the configured defer environment and relation availability.
- **Closing build includes answer key:** stop and rerun with `--exclude tag:optimized`.
- **Closing time is slower:** discuss concurrency, cache, changed materializations, clustering write cost, and why elapsed time alone is insufficient.

## Take-home close

After the workshop, direct attendees to `models/answer_key/` and its companion notes as the durable reference they can compare with the assets built in their temporary branches.

Close with:

> Optimize the work the warehouse performs, prove the result at the right cost surface, and encode enough grain, testing, and job context to keep the waste from coming back.
