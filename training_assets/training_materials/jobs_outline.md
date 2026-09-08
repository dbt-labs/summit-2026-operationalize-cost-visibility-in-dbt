# Job optimization playbook

This is the trainer-facing source of truth for recreating the workshop jobs after the project moves to the workshop dbt account.

The job section demonstrates that model SQL is only one cost surface. Selector scope, test scope, dbt State, deferral, model reuse, and environment cleanup all affect warehouse work.

## Live-demo rule

Trigger only the prepared dbt State/model-reuse job live. All CI, benchmark, test-scope, and cleanup comparisons should be run before the workshop and presented through saved runs, artifacts, and screenshots.

The bulk of this module should explain dbt State:

- what artifacts are compared;
- how changed resources are identified;
- when existing relations can be reused;
- how state selection differs from ref deferral; and
- which code, environment, and source changes invalidate reuse assumptions.

Target module time: 20 minutes, including the final attendee build and wrap-up.

## Workshop commands

Attendee full builds exclude the take-home answer key:

```text
dbt build --exclude tag:optimized
```

Trainer benchmark commands remain:

```text
dbt build --select +tag:unoptimized
dbt build --select +tag:optimized
```

The enabled optimized models are trainer reference and take-home assets. Do not build them in attendee schemas during the live workshop.

## Job inventory to create

| Job/evidence | Workshop use | Core command/configuration | Live? |
|---|---|---|---|
| Starter benchmark | Stable before evidence | `dbt build --select +tag:unoptimized` | No |
| Optimized benchmark | Stable after evidence | `dbt build --select +tag:optimized` | No |
| CI before | Show broad or incomplete state-based validation | `dbt build --select state:modified+` | No |
| CI after | Show cautious indirect selection and explicit incremental validation | Commands in the CI section | No |
| State/reuse before | Show repeated work with reuse disabled | `dbt build --exclude tag:optimized` | No |
| State/reuse after | Demonstrate configured dbt State/model reuse | Same command with State/reuse enabled | Yes |
| Test-scope audit | Compare selected tests and expensive unrelated work | `dbt ls` evidence and saved runs | No |

Record these settings for every paired run:

- warehouse and warehouse size;
- target name;
- thread count;
- dbt State/model-reuse setting;
- comparison and deferral environments;
- schema-generation behavior;
- timeout;
- source snapshot or ingestion window; and
- schedule or trigger behavior.

Keep settings stable unless the setting itself is the optimization being demonstrated.

## Prepared evidence 1: benchmark jobs

### Starter

```text
dbt build --select +tag:unoptimized
```

### Optimized

```text
dbt build --select +tag:optimized
```

Use saved runs to compare:

- total and per-model runtime;
- bytes scanned;
- rows entering and leaving expensive joins;
- rows written or merged;
- pruning behavior;
- test runtime; and
- warehouse credits where available.

The current whole-project elapsed-time comparison is 3:13 versus 2:46, a 14.0% reduction. Explain why shared upstream work and tests dilute that number and why clustering/persistence ROI is better represented in recurring consumption queries.

## Prepared evidence 2: CI optimization

### Before

```text
dbt build --select state:modified+
```

### After

```text
dbt run-operation reset_pr_schemas

dbt build --select state:modified+ --indirect-selection cautious

dbt build --select state:modified+,config.materialized:incremental --indirect-selection cautious
```

The supporting cleanup macro is `macros/utils/reset_pr_schemas.sql`.

Walk through these points using saved runs:

- indirectly selected tests may be broader than the CI intent;
- modified incremental models need explicit validation of incremental behavior;
- net-new incrementals in reusable PR schemas can retain incompatible target state;
- `--indirect-selection cautious` runs a test only when all parents are selected; and
- cleanup controls abandoned-schema storage and avoids stale incremental targets.

Do not trigger these jobs live. Show selected-node counts, runtime, credits, and cleanup behavior from the prepared runs.

## Live demo: dbt State and model reuse

Use the same project revision, environment, warehouse, thread count, and selector for each paired run. The workshop has two valid comparison paths:

```text
# Starter graph
dbt build --exclude tag:optimized

# Optimized graph
dbt build --exclude tag:unoptimized
```

Choose one path for a before/after pair and do not switch selectors between runs.

### Project configuration for this workshop

The project sets:

```yaml
models:
  merlinco_apothecaries:
    +state:
      lag_tolerance: "0s"
```

`lag_tolerance` is a debounce window after upstream data changes, not a statement that data may be stale for that long. The default is 45 minutes: when upstream data changes, State waits until that change is older than 45 minutes before making the downstream node eligible to rebuild. This workshop uses `0s` because the raw data is static except for the three intentional batch-ingestion scripts; each batch should invalidate affected nodes immediately.

### State configs in plain English

| Config | Default | Meaning | Workshop guidance |
|---|---|---|---|
| `lag_tolerance` | `45m` | How long to buffer an upstream data change before rebuilding | Project-wide `0s` so scripted batches are visible immediately |
| `require_fresh_data_from` | `any` | Rebuild eligibility starts when any direct parent is fresh; `all` waits for every parent | Keep `any`; `all` could hide a one-table correction or late payment |
| `evaluate_volatile_sql` | `false` | Whether runtime values from `current_date`, `current_timestamp`, random functions, and similar expressions invalidate reuse | Keep `false` for the live same-day demo; use `true` only on a node whose business result must change when the volatile value changes |
| `pre_clone` | `if_missing` | Whether State clones an existing incremental model or snapshot before running in a schema where the target is absent | Keep the default; this mainly matters for development/CI or another fresh schema |
| `execute_hooks_on_any_reuse` | `false` | Whether pre- and post-hooks execute when State reuses a node without rebuilding it | Keep `false`; no workshop model requires hooks on reuse |

`metadata_warehouse` and `defer_to_target` are profile/environment settings rather than model behavior. They control where State metadata queries run and which environment supplies deferred relations.

### Why staging uses explicit columns

State always rebuilds a view when its SQL contains `select *` anywhere, including an imported source CTE or a final `select * from renamed`. State cannot prove that the resolved view column set is unchanged without inspecting upstream schema metadata.

The workshop staging views therefore list source and output columns explicitly. `dbt_utils.star()` can render an explicit list, but it performs compile-time relation introspection and makes the compiled SQL depend on discovered warehouse metadata. Explicit lists give this demo the most deterministic execution hash and make source schema changes intentional code changes.

This is a State-specific tradeoff with the common staging pattern; it is not a claim that imported source CTEs are generally bad dbt style.

### Prepared before run

1. Keep dbt State disabled.
2. Run the chosen graph twice without code or source changes.
3. Save work performed, selected-node count, runtime, tests, and credits.

### Prime State before the live demo

The first State-enabled run establishes State's execution hashes and freshness baseline. It is not the reuse result to present. An incremental model may also compile differently on its first and second executions because `is_incremental()` changes from false to true; State correctly treats that as a SQL change.

1. Enable dbt State on the matching job.
2. Run it once to establish the baseline.
3. Run it again with no code or source changes.
4. Save the second run as fallback evidence; persisted models and eligible tests should be reused.

### Live sequence with the workshop batches

1. Trigger the already-primed State job with no new ingestion. Explain that unchanged staging views, marts, and eligible tests can be reused.
2. Run one of these scripts against `APOTHECARIES.RAW`:
   - `training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql`
   - `training_assets/snowflake_scripts/05_weekly_orders_change_batch_2.sql`
   - `training_assets/snowflake_scripts/06_weekly_orders_change_batch_3.sql`
3. Trigger the same State job again. With `lag_tolerance: 0s`, changes to `RAW_ORDERS`, `RAW_ORDER_ITEMS`, and `RAW_PAYMENTS` are immediately eligible to rebuild their staging views and affected descendants; unrelated source branches should remain reusable.
4. Trigger once more without another ingestion to show reuse returning after the changed-data run establishes a new baseline.

### Required distinctions

- dbt State compares rendered logic, relevant configuration, relation availability, and upstream freshness to choose reuse, clone, or normal build.
- The initial State-enabled run is baseline capture; the next unchanged run demonstrates reuse.
- State-based selection such as `state:modified+` determines which nodes enter a command. It is separate from managed dbt State reuse.
- Deferral controls where unresolved `ref()` calls read from; reuse controls whether a selected node needs execution.
- A matching command does not guarantee matching work. Code revision, target schema, materialization state, source timestamps, and the `is_incremental()` branch all affect eligibility.
- A State freshness-cache warning means dbt fell back to per-relation metadata queries; it does not mean the model or source freshness test failed.

If the live run is slow or queued, switch to the saved second State-enabled run and continue without waiting.


## Prepared evidence 3: test-scope audit

Useful inspection commands:

```text
dbt ls --select tag:unoptimized --resource-type test --output name
dbt ls --select tag:optimized --resource-type test --output name
dbt ls --select +tag:unoptimized --resource-type test --output name
dbt ls --select +tag:optimized --resource-type test --output name
```

Discuss:

- grain and relationship tests that protect expensive join assumptions;
- why missing or weak validation can let fanout and unnecessary compute recur;
- why heavyweight tests may belong in deploy or scheduled quality jobs; and
- why targeted CI still needs explicit incremental validation.

Contracts and shape protection are supporting controls. Keep the workshop focus on how missing guarantees can create recurring performance and cost problems.

## Presenter sequence

1. Show the prepared broad-job symptom and its cost.
2. Explain the before/after configuration and commands.
3. Spend most of the segment on dbt State and deferral concepts.
4. Trigger the State/reuse job live.
5. Use prepared CI and test-scope runs while the live job completes.
6. Compare the live result with the prepared before run.
7. Have attendees run the closing `dbt build --exclude tag:optimized`.
8. Wrap with whole-build, focal-model, consumption-query, and annualized cost evidence.

## Workshop-account setup checklist

1. Create development, CI, and production environments.
2. Create the jobs in the inventory table.
3. Configure production comparison state and deferral targets.
4. Confirm the CI schema naming convention and cleanup macro behavior.
5. Pin warehouse size and threads for repeatable comparisons.
6. Run every prepared job at least twice and save expected selected-node counts.
7. Capture successful fallback screenshots and run artifacts.
8. Record final job IDs, environment IDs, and UI navigation in `training_assets/demo_outlines/06_optimize_jobs_and_test_scope.md`.
9. Rehearse the single live State job under expected workshop concurrency.

## Decisions to finalize during account setup

- final job names;
- final production comparison and defer environments;
- warehouse size and thread count;
- exact live State-job selector if a narrower scope tells the story more clearly;
- tests used for the clearest over-selection example; and
- reset ownership between workshop deliveries.
