# Deck slide outlines

On-slide content and speaker notes for slides drafted during the deck refresh.

- **Deck:** Summit '26 — Operationalize cost visibility in dbt
- **Scope of this file:** Module 4, dbt State portion
- **Sources:** `training_assets/demo_outlines/06_optimize_jobs_and_test_scope.md`, `docs/training_materials/jobs.md`, https://www.getdbt.com/product/dbt-state

Timings are rough projections pending the dry run.

---

## Module 4 — dbt State

Sequenced to run after the right-sizing slides and the two project-hygiene / slim CI
slides.

**Ordering note:** because slim CI comes first and introduces `state:modified+`,
slide 3 ("Selection is not reuse") is required rather than optional. Without it,
attendees will assume the selector *is* dbt State.

---

### Slide 1 — Build what's changed, skip what hasn't

**Timing:** ~1.5 min

**On-slide**

- Checks metadata and model SQL on **every run** — no custom workflows, no manual orchestration
- **30% average** warehouse compute reduction
- Applies to models, incrementals, snapshots, seeds, **and tests**
- dbt Core 1.7+ plugin or the dbt platform · works with Airflow, Dagster, and others
- Status: **Preview**

**Speaker notes**

Everything in this module so far has been about making work cheaper. This slide is
about not doing the work at all.

Every optimization we made today still runs on every scheduled build. We clustered
a table, we persisted a dimension, we made a fact incremental, we refactored a mart
— and all of that still executes, every night, whether or not anything changed.
dbt State asks a different question: did anything actually change?

Note that this covers tests, not just models. We have been building and running
tests all day. In a mature project, reused test results are often a larger share of
the avoided work than reused models.

The analogy: you would not repaint the entire house because you touched up one room.
dbt State brings that logic to your pipelines.

---

### Slide 2 — How dbt State decides

**Timing:** ~2 min

**On-slide — what it compares**

- Rendered model SQL
- Relevant configuration
- Relation availability
- Upstream data freshness

**On-slide — what it then does**

| Outcome | Cost |
|---|---|
| **Reuse** existing state | zero compute, zero risk |
| **Clone** existing state | minimal compute |
| **Auto-defer** to production state (in development) | zero compute |

**Speaker notes**

This is the slide people misremember, so I want to be precise.

dbt State is not diffing your git branch. It compares four things, and all four
matter. The rendered model SQL — that is after Jinja resolves, not the template.
The configuration that affects the relation. Whether the relation actually exists in
the target. And whether the upstream data moved.

That last one is why a run can legitimately rebuild something when you changed no
code at all. Your SQL is identical, but a source landed fresh data, so the
downstream result is no longer current.

On the outcomes: reuse means the existing relation is left completely alone — zero
compute. Clone is for cases where a relation needs to exist in this schema but does
not need recomputing, which mostly matters for incrementals and snapshots in a fresh
development or CI schema. Auto-defer, in development, points unresolved references
at production instead of building upstream models locally.

---

### Slide 3 — Selection is not reuse

**Timing:** ~1.5 min

**On-slide**

| | Decides | Mechanism |
|---|---|---|
| `state:modified+` | which nodes **enter** the command | selector, resolved before the run |
| **dbt State** | whether selected work needs **executing** | evaluated per node, during the run |

> They compose. Selection narrows the graph; dbt State can then skip work inside what is left.

**Deferral** is a third, separate thing — it resolves unresolved `ref()` calls to
another environment's relations.

**Speaker notes**

We just used `state:modified+` in our CI job, and it is easy to assume that is dbt
State. It is not, and the distinction matters when you start configuring this
yourself.

The selector compares your project manifest against a previous one and picks nodes.
That is a selection decision, made before anything runs. dbt State asks, node by
node during the run, whether the work is actually necessary.

You can use either one alone, or both together. In CI you usually want both: select
the changed slice with the selector, then let dbt State skip whatever inside that
slice is still valid.

Deferral is the third piece and it answers a different question again — not "what
should run" or "does this need to run," but "where do I read from for the things
that are not running here."

---

### Slide 4 — Declaring freshness rules in project code

**Timing:** ~2 min

**On-slide**

| Config | Default | What it controls |
|---|---|---|
| `lag_tolerance` | `45m` | Debounce window after an upstream change before rebuild is eligible |
| `require_fresh_data_from` | `any` | One fresh parent triggers; `all` waits for every parent |
| `evaluate_volatile_sql` | `false` | Whether `current_date` and similar invalidate reuse |
| `pre_clone` | `if_missing` | Clone incrementals/snapshots into a fresh schema before running |
| `execute_hooks_on_any_reuse` | `false` | Whether hooks fire on a reused node |

**On-slide — this project**

```yaml
models:
  merlinco_apothecaries:
    +state:
      lag_tolerance: "0s"
```

**Speaker notes**

These are set at the project, folder, or model level, in code, version controlled —
the same pattern as every other config we have touched today.

One correction I want to make directly, because it is the most common misreading:
`lag_tolerance` is a debounce window, not a tolerance for stale data. The default of
45 minutes means dbt waits until an upstream change is 45 minutes old before making
downstream models eligible to rebuild. That batches up chatty sources instead of
thrashing on every single arrival.

We set it to zero seconds for this workshop because our raw data only changes when I
deliberately run a batch script, and I want that change to be visible immediately.

`require_fresh_data_from: any` is worth a sentence as well. Switching it to `all`
sounds conservative, but it means a single-table correction will not rebuild anything
until every parent refreshes — which would hide exactly the late-refund scenario we
built our incremental model to catch.

---

### Slide 5 — Demo: baseline versus reuse

**Timing:** ~3 min — the payoff

**On-slide — two runs, same job, same command, same code**

```text
dbt build --exclude tag:unoptimized
```

**On-slide — what to compare**

- Nodes **built** vs. **reused**
- Tests **executed** vs. **reused**
- dbt-step runtime and total job runtime
- The residual execution surface — what still ran, and why

**Speaker notes**

The most important framing here: the first State-enabled run is not the demo. The
first run captures execution hashes and establishes the freshness baseline. The
second run, with nothing changed, is the reuse result. That is the one to present.

If you show a first run and everything rebuilds, the natural conclusion is that the
feature does not work.

Walk the residual execution surface honestly. Some things will still run, and being
able to explain exactly why is what makes this credible instead of magical.

**Delivery note:** if triggering live, keep the saved second run open in another tab
as a fallback. Queue time under workshop concurrency is the one variable outside our
control.

---

### Slide 6 — Why did that rebuild?

**Timing:** ~2 min — the slide that makes this usable on Monday

**On-slide — four reasons unchanged code still rebuilds**

| Cause | Why |
|---|---|
| **First State-enabled run** | Baseline capture, not a reuse failure |
| **`select *` anywhere in a view** | State cannot prove the resolved column set is unchanged |
| **Incremental transition run** | `is_incremental()` flips false to true, so rendered SQL genuinely changed |
| **Ephemeral models** | No relation exists to reuse; their tests stay in the executed surface |

**Speaker notes**

This is the troubleshooting slide, and it is the one people will thank you for.

The `select *` case is the most actionable, and it connects back to our
materialization demo. A view whose SQL contains `select *` anywhere — including
inside an imported source CTE — always rebuilds, because dbt State cannot verify the
resolved column set without introspecting upstream schema. That is why the staging
models in this project list their columns explicitly.

Be fair about the tradeoff: that is a dbt State–specific consideration, not a claim
that source CTEs are bad dbt style.

The incremental case prevents a false bug report. The run right after you convert a
model to incremental will rebuild, correctly, because `is_incremental()` changed the
rendered SQL. That is not State misbehaving.

And if you see a freshness-cache warning in the logs, that means dbt fell back to
per-relation metadata queries. It is not a failed source freshness test.

---

## Cut order if the dry run runs long

1. Compress slide 6 to a half-slide of bullets
2. Merge slides 1 and 2

Protect slide 3 and slide 5: one prevents the module's central confusion, the other
is the only place the room sees reuse actually happen.
