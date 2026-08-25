# Demo 06: optimize jobs and test scope

## Audience outcome

Attendees can distinguish full-build optimization, managed dbt State, state-based selection, deferral, and model reuse; recognize unnecessary job/test work; and interpret the workshop's prepared job evidence.

## Timing and interaction

- **Current planning budget:** 20 minutes; validate during the dry run.
- **Mode:** guided inspection of prepared dbt Platform job executions, followed by the attendee closing build and workshop wrap-up.
- **Live operations:** no dbt Platform jobs are triggered during this module. Attendees start their own closing build after the prepared-run walkthrough.
- **Prepared evidence:** State-disabled unoptimized and optimized production builds, State baseline and reuse runs, and one successful CI run from a sample PR.

## Setup and prerequisites

Open these prepared executions in separate browser tabs before the workshop:

1. `Prod | Unoptimized | State Disabled` — full starter graph.
2. `Prod | Optimized | State Disabled` — full optimized graph.
3. `Prod | Optimized | State Enabled` — first State-enabled baseline run.
4. `Prod | Optimized | State Enabled` — second unchanged run showing reuse.
5. `CI` — a successful run from a sample PR that remains available for inspection.

Confirm before presenting:

- The two State-disabled production runs use the same Git SHA, environment, warehouse, threads, target, and source state. Their only intentional difference is starter versus optimized model selection.
- The two State-enabled runs use the same Git SHA, environment, command, and source state. The first establishes State metadata; the second demonstrates reuse.
- The CI run has production deferral available and completed enough steps to show cleanup, modified-node selection, and incremental validation.
- Staging views use explicit column lists. Views containing `select *` anywhere are rebuilt by State and weaken the reuse evidence.
- The project config sets `lag_tolerance: "0s"`, so the intentional batch-ingestion scripts invalidate affected nodes immediately when those scripts are used elsewhere in the workshop.
- Attendees have their opening full-build runtime from Demo 00.

## Facilitator flow

### 1. Compare the prepared State-disabled builds — 4 minutes

Open these two completed jobs side by side:

```text
# Starter graph
Prod | Unoptimized | State Disabled
dbt build --exclude tag:optimized

# Optimized graph
Prod | Optimized | State Disabled
dbt build --exclude tag:unoptimized
```

Use these runs as the raw before/after implementation comparison. Managed State is disabled on both, so model reuse does not distort the evidence.

Compare:

- total and per-model runtime;
- models and tests executed;
- the shared source-to-mart work in both graphs;
- focal optimized model timings;
- rows written or merged;
- warehouse time or credits where available; and
- why whole-project elapsed time can understate the value seen in focal model and consumption-query evidence.

Keep this comparison separate from the State walkthrough. It answers, "What changed when we implemented the workshop optimizations?"

### 2. Walk through the prepared State baseline and reuse runs — 6 minutes

Open the two completed executions from `Prod | Optimized | State Enabled`. Both use:

```text
dbt build --exclude tag:unoptimized
```

Show the first run as the State baseline and the second unchanged run as the reuse result. Compare:

- built versus reused nodes;
- test results reused versus executed;
- dbt-step and total job runtime;
- the small residual execution surface, including tests over ephemeral intermediates; and
- any State freshness metadata messages.

Cover these distinctions explicitly:

- **Managed dbt State:** compares rendered logic, relevant config, relation availability, and upstream freshness to choose reuse, clone, or a normal build.
- **First versus second State run:** the first run captures State metadata and execution hashes; the next unchanged run demonstrates reuse.
- **State selector:** expressions such as `state:modified+` determine which nodes enter a command and are separate from managed State reuse.
- **Deferral:** eligible `ref()` calls resolve to existing relations in another environment.
- **Model reuse:** selected unchanged work can be skipped or cloned instead of recomputed.
- **Incremental compilation:** the initial full-load branch and later `is_incremental()` branch can produce different rendered SQL, so a transition run may correctly rebuild even without a code edit.
- **Ephemeral models:** they have no warehouse relation to reuse; tests against ephemeral logic may remain part of the executed validation surface.

Explain the workshop State config in plain English:

- `lag_tolerance: "0s"` means an upstream change is eligible to rebuild immediately. The default `45m` is a debounce window after a change.
- `require_fresh_data_from: any` means one changed direct parent is enough to make a node eligible for rebuilding.
- `evaluate_volatile_sql: false` treats `current_date` and similar expressions as stable for reuse. Turn it on only where the changing runtime value must refresh the business result.
- `pre_clone: if_missing` mainly supports incrementals and snapshots in fresh development or CI schemas.
- `execute_hooks_on_any_reuse: false` avoids executing hooks when the model itself is reused.

The raw workshop data is static except when the trainer applies:

- `04_weekly_orders_change_batch.sql`
- `05_weekly_orders_change_batch_2.sql`
- `06_weekly_orders_change_batch_3.sql`

If a batch has been applied, explain that the next State run should rebuild the three affected Abra POS staging views and their descendants while retaining reuse on unrelated branches. Do not run a batch or trigger another job during this module.

### 3. Inspect the prepared optimized CI pattern — 4 minutes

Open the successful run from the sample PR. This is one optimized CI pattern to explain, not a CI before/after comparison.

The job runs:

```text
dbt run-operation reset_pr_schemas

dbt build --select state:modified+ --exclude tag:optimized

dbt build --select state:modified+,config.materialized:incremental --exclude tag:optimized
```

Walk through each step:

1. `reset_pr_schemas` removes abandoned PR schemas so stale incremental state and storage do not accumulate.
2. `state:modified+` selects changed resources and affected descendants instead of rebuilding the full starter project.
3. `state:modified+,config.materialized:incremental` intersects the modified downstream closure with incremental materialization, explicitly exercising affected incremental behavior.
4. `--exclude tag:optimized` keeps take-home answer-key models out of attendee CI.
5. Production deferral supplies unchanged upstream relations that are not built in the PR schema.
6. Managed State can further reuse eligible selected work; selection determines what enters the command, while State determines whether selected work needs execution.

Inspect:

- selected, built, reused, and skipped nodes;
- tests associated with the changed slice;
- the deferred production run/environment;
- the PR schema name and cleanup behavior; and
- the incremental model's target state and merge behavior.

### 4. Connect the three job stories — 1 minute

Summarize the distinct question answered by each prepared execution:

- **State-disabled starter versus optimized:** Did the implemented model and physical-design changes improve the raw build?
- **State baseline versus reuse:** How much unchanged work can dbt avoid?
- **Prepared CI run:** How can a PR validate the affected graph and incremental behavior without rebuilding everything?

Do not combine their runtimes into one before/after claim; each comparison isolates a different cost-control mechanism.

### 5. Start the closing attendee build — 1 minute

Have attendees run:

```text
dbt build --exclude tag:optimized
```

This is the second and final full build in each attendee's own development schema. Ask them to record the result and compare it with their opening build from Demo 00.

### 6. Wrap the cost story while attendee builds run — 4 minutes

Use `training_assets/demo_outlines/07_conclusion_notes.md` as the source for the wrap-up slides and speaker notes.

Cover only the conclusions that fit the rehearsed time:

- why full-build runtime is only one cost surface;
- why clustering and persistence pay back primarily through repeated consumption;
- why incremental savings appear on recurring changed-data runs;
- why shared upstream models and tests dilute whole-project percentages;
- why State avoids unchanged work rather than making SQL itself faster; and
- why CI selection reduces feedback time without replacing broader scheduled validation.

If attendee builds are still running, close with the prepared evidence and have attendees review their final duration afterward.

## Decision checkpoint

Ask:

> When should a job use `state:modified+`, and when should it still run a broader scheduled validation?

Expected answer: state-scoped CI gives fast feedback on changed resources and affected descendants; broader deploy or scheduled jobs still provide complete quality coverage, source freshness, and protection against assumptions outside the code diff.

## Validation and evidence

Required prepared evidence:

- State-disabled starter and optimized production runs with comparable settings and source state;
- first and second State-enabled optimized runs with the same code and source state;
- a successful sample-PR CI run with production deferral visible;
- selected, built, reused, skipped, and tested node counts where the UI exposes them;
- job runtimes and warehouse time or credits where available; and
- focal-model and consumption-query evidence from Demos 01–05.

Keep the comparisons scoped correctly:

- use the State-disabled pair for implementation before/after;
- use the two State-enabled runs for baseline/reuse;
- use the CI run to explain an optimized workflow, not to claim model runtime improvement; and
- use attendee opening/closing builds only within each attendee's own comparable environment.

## Common failures and recovery

- **Prepared runs use different Git SHAs or source states:** do not present them as a controlled pair; use fallback screenshots or rerun before the workshop.
- **State reuse evidence is weak:** verify the State job was primed, staging views are reuse-eligible, and no batch ingestion occurred between the two saved runs.
- **Sample PR run is cancelled because the PR closed:** keep the PR open through the workshop or save screenshots and run artifacts beforehand.
- **Deferral resolves unexpectedly:** verify the CI job's production defer environment and relation availability.
- **Closing build includes answer-key models:** stop and rerun with `--exclude tag:optimized`.
- **Closing time is slower:** discuss concurrency, cache, changed materializations, clustering write cost, and why elapsed time alone is insufficient.

## Take-home close

After the workshop, direct attendees to `models/answer_key/` and its companion notes as the durable reference they can compare with the assets built in their temporary branches.

Close with:

> Optimize the work the warehouse performs, prove the result at the right cost surface, and encode enough grain, testing, and job context to keep the waste from coming back.
