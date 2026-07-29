# Job optimization playbook

This document is the concise trainer-facing runbook for the job optimization section of the workshop.

The goal is to keep the job story simple while still covering the highest-value operational cost optimizations in dbt.

## What the job section is meant to demonstrate

The workshop should show that cost optimization is not only about model SQL. Job configuration also matters.

The two main job stories are:

1. **CI optimization**
   - selectors
   - test scope
   - incremental validation
   - PR-schema cleanup for net-new incrementals

2. **dbt State / model reuse**
   - repeated runs of the same job
   - before/after behavior once State is enabled

## Job 1: CI optimization

This is the main job-audit demo.

### Before

```text
dbt build --select state:modified+
```

### Problem

This is a realistic starting point, but it still has important gaps:

- it does not explicitly test incremental logic for modified incremental models
- it does not have an automated way to handle schema changes for net-new incremental models in PR schemas
- it is overly inclusive of tests that get pulled in by default indirect selection

The result is wasted compute and brittle CI behavior, especially when incremental models are being developed in pull requests.

### After

```text
dbt run-operation reset_pr_schemas

dbt build --select state:modified+ --indirect-selection cautious

dbt build --select state:modified+,config.materialized:incremental --indirect-selection cautious
```

### Solution

This improved CI pattern demonstrates several optimizations at once:

- tests are scoped more neatly through `--indirect-selection cautious`
- compute is preserved by keeping validation targeted
- incremental logic is tested explicitly for modified incremental models
- PR-schema cleanup reduces repeated CI failures caused by schema drift on net-new incremental models

### What to call out in the demo

- the command is still state-based, but the after-state is more deliberate about what gets tested
- the incremental-specific second build is what closes the validation gap
- `reset_pr_schemas` is primarily an operability and wasted-compute improvement

### Supporting asset

- `macros/utils/reset_pr_schemas.sql`

## Job 2: dbt State demo

This is the clean before/after demo for model reuse.

### Before

Use a straightforward repeated-build job on a meaningful slice of the project.

Recommended command:

```text
dbt build --select fct_orders+
```

Optional broader version if you want a slightly bigger surface area:

```text
dbt build --select fct_orders+ fct_order_items+
```

### Problem

Without dbt State enabled, repeated runs of the same job still rebuild models unnecessarily. The job has no state context to help it understand what can be reused.

This is the simplest way to show the audience that repeated job cost is not only about SQL quality — it is also about how the job is configured.

### After

**State enabled. Same job command.**

```text
dbt build --select fct_orders+
```

Or, if using the broader version:

```text
dbt build --select fct_orders+ fct_order_items+
```

### Solution

Once dbt State is enabled, subsequent runs can reuse prior work much more effectively.

This is the core lesson:

- models are only rebuilt if the code has changed
- or if the underlying data has changed
- repeated runs stop doing unnecessary work

### Recommended demo flow

#### Before State

1. trigger the job
2. review runtime / work done
3. trigger the same job again
4. show that repeated work is still happening

#### After State

1. enable dbt State in the job/environment configuration
2. trigger the same job
3. trigger it again
4. compare reused work, runtime, and overall behavior

### What to call out in the demo

- the SQL did not change between the before and after demo
- the job command did not need to change
- the improvement comes from dbt State, not from changing business logic

## Why these two jobs are enough

Together, these two demos cover the main job-level cost optimization areas we want to teach:

- selector scope
- test scope
- incremental validation
- CI hygiene
- state and model reuse

That keeps the workshop focused and avoids turning the jobs section into a long tour of job administration.

## Presenter framing

For both jobs, use the same structure in the deck:

- before command(s)
- problem
- after command(s) / configuration
- solution
- expected benefit

## Open configuration tasks

Still need to finalize in dbt:

- the exact job names
- the exact environment settings for dbt State
- whether the State demo uses `fct_orders+` only or also includes `fct_order_items+`
- which tests you most want to highlight as overly inclusive in the CI before-state
