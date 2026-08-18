# Demo 06: optimize jobs and test scope

## Audience outcome

Attendees can distinguish dbt State, state-based selection, deferral, and model reuse; recognize unnecessary job/test work; and interpret the workshop's full-build and annualized cost evidence.

## Timing and interaction

- **Current planning budget:** 20 minutes; validate during the dry run.
- **Mode:** follow-along platform demo and workshop wrap-up.
- **Live operations:** one dbt State/model-reuse job and the attendee closing full build.
- **Prepared operations:** CI, benchmark, test-scope, cleanup, and no-State comparison runs.

## Setup and prerequisites

- The workshop account has a rehearsed State/model-reuse job.
- A successful fallback run is available if the live job queues or fails.
- Prepared before/after CI, benchmark, and test-scope runs are open in browser tabs.
- Job environment, warehouse, threads, state comparison, and deferral settings are recorded.
- Attendees have their opening full-build runtime from Demo 00.

## Facilitator flow

### 1. Trigger the State/model-reuse job — 1 minute

Trigger the prepared job once. Its command should exclude the take-home answer key:

```text
dbt build --exclude tag:optimized
```

Do not trigger the benchmark, CI, or test-scope jobs live.

### 2. Explain dbt State while the job runs — 7 minutes

Cover these distinctions explicitly:

- **State artifact:** a prior manifest represents a comparison point for project resources.
- **State comparison:** dbt identifies resources that are new, modified, or unchanged.
- **State selector:** expressions such as `state:modified+` control which nodes enter a command.
- **Deferral:** eligible `ref()` calls resolve to existing relations in another environment.
- **Model reuse:** supported platform configuration avoids recomputing eligible unchanged work.

Use one lineage example from the workshop. Explain why code revision, environment configuration, state artifact, source behavior, and relation availability all affect whether reuse is safe.

### 3. Show prepared job evidence — 5 minutes

Walk through saved runs rather than waiting for execution:

- broad benchmark before/after;
- CI `state:modified+` before;
- cautious indirect test selection after;
- explicit modified-incremental validation;
- PR-schema cleanup; and
- selected test counts.

Connect gaps in test and state configuration to cost: broad selection repeats expensive work, while overly narrow selection can miss the assumptions that keep incremental and join behavior safe.

Keep contracts as supporting context. The module focus is avoiding unnecessary warehouse work without weakening validation.

### 4. Review the live State result — 2 minutes

Compare the live run with the prepared no-reuse run:

- selected and reused work;
- runtime;
- credits or warehouse time; and
- any nodes that correctly rebuilt.

If the job is still queued or running, switch to the saved successful after run and keep the workshop moving.

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
