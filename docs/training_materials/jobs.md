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

Use the same command in the before and after job definitions:

```text
dbt build --exclude tag:optimized
```

### Prepared before run

1. Keep dbt State/model reuse disabled.
2. Run the job twice without code or source changes.
3. Save the work performed, selected-node count, runtime, and credits.

### Live after run

1. Enable dbt State/model reuse in the job or environment.
2. Configure the correct comparison state and deferral target.
3. Trigger the prepared job once live.
4. While it runs, explain the artifact comparison and reuse decision.
5. Compare the completed run with the saved before run.

### Required distinctions

- State comparison identifies new, modified, and unchanged resources.
- State-based selection controls which resources are selected.
- Deferral controls where eligible `ref()` calls resolve.
- Model reuse avoids recomputing eligible unchanged work when the platform and job configuration support it.
- A matching command does not guarantee matching work; the environment, state artifact, code revision, and relation availability matter.

If the live run is slow or queued, switch to the saved successful after run and continue the explanation without waiting.

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
