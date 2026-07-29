# dbt Summit training notes: cost optimization through dbt

## Purpose

This project will be used in a dbt Summit training on cost optimization through dbt, using dbt + Snowflake as the working example. The workshop should teach principles that transfer cleanly to other warehouse platforms as well, including BigQuery, Databricks, and Redshift.

The core story is that using dbt correctly helps teams do two things:

1. make queries run faster
2. make queries read less data

The workshop should use intentional anti-patterns in this repo so attendees can work through the full FinOps cycle:

1. identify the symptom
2. diagnose the root cause
3. apply the dbt fix
4. put a prevention mechanism in place

## Repo structure for the workshop

Attendees will work in the primary project models:

- `models/staging/`
- `models/intermediate/`
- `models/marts/`

The "after" state should live in `models/answer_key/` for comparison and instructor reference. The answer key is not built in normal project runs, so it can safely hold corrected versions of workshop examples.

Important note: today, `models/answer_key/` is currently populated for the procurement lab only. For this training, additional answer key models may need to be added there to represent the optimized end state of the cost-focused exercises.

## Workshop design principles

### Organize every section around a symptom

Each module should follow the same sequence:

1. **Symptom** — what users notice first
2. **Diagnosis** — how to confirm what is causing the cost/performance issue
3. **dbt fix** — the direct modeling or job configuration change
4. **Prevention** — the convention, selector, contract, test, or review rule that prevents recurrence

This keeps the training grounded in real operational behavior instead of abstract best practices.

### Prioritize high-impact, low-effort fixes first

The workshop should spend the most time on optimizations that are both common and highly actionable in dbt:

1. materialization strategy
2. incremental build strategy
3. job scope optimization with state/deferral/slim CI
4. refactoring messy SQL into modular dbt models
5. test scope optimization

Later sections can cover more advanced or lower-frequency patterns such as clustering, write amplification, storage, and spill-focused diagnosis.

### Make the anti-patterns intentional and legible

The goal is not to make the repo randomly bad. Each bad example should have a clear causal story so the workshop can demonstrate:

- what the symptom looks like
- how to inspect it
- how to change the dbt project to fix it
- how to prevent it from happening again

## Learning goals

By the end of the workshop, attendees should be able to:

- connect a warehouse symptom to a dbt design or configuration decision
- identify when a model has the wrong materialization
- identify when a large table should be incremental
- recognize when poor pruning, unhealthy joins, or repeated computation are driving cost
- use dbt model layering to refactor expensive SQL into better architecture
- reduce job cost with selectors, state, deferral, and targeted test execution
- distinguish model-level, job-level, and storage-level optimization opportunities
- use dbt conventions as proactive FinOps guardrails

## Recommended workshop framing

Frame the training in three optimization layers:

### 1. model-level optimization

Fastest feedback loop and easiest to make tangible:

- view vs table vs incremental
- bad incremental strategy
- unhealthy joins and fanout
- repeated computation and ephemeral overuse
- modular refactoring of messy SQL
- pruning and clustering candidates

### 2. job-level optimization

Often where org-wide cost savings show up most clearly:

- broad selectors
- rebuilding too much of the DAG
- retesting too much of the DAG
- state and deferral
- slim CI
- job decomposition by purpose

### 3. storage-level optimization

Good hygiene and environment-aware configuration:

- transient vs permanent tables
- clone awareness
- retention and churn awareness
- avoiding unnecessary rewrites

## Symptom-to-optimization map

This is the backbone of the workshop.

### 1. long-running queries against a model

Possible causes to demonstrate:

- model is materialized as a `view` but is queried often and is expensive to recompute
- model SQL is too complex because too much logic is packed into one statement
- repeated heavy logic is being inlined through ephemeral models
- underlying table is large and not pruning effectively

Direct dbt optimizations:

- change `view` to `table`
- split one oversized model into multiple staging/intermediate/mart models
- persist heavy reusable logic rather than inlining it repeatedly
- add warehouse-specific physical design optimization, such as clustering, when the access pattern supports it

Prevention themes:

- materialization review during model design
- layering rules and modular SQL conventions
- avoid marts that double as giant transformation pipelines
- document model purpose and access pattern

### 2. long-running model builds / high-credit model queries

Possible causes to demonstrate:

- table should be incremental
- incremental model has a poor filter strategy and still scans too much data
- expensive joins are creating row explosion or unnecessary shuffles
- model rewrites large amounts of unchanged data

Direct dbt optimizations:

- convert `table` to `incremental`
- apply a selective and correct incremental predicate
- refactor joins to align grains before joining
- isolate changed-key logic to reduce write amplification

Prevention themes:

- incremental readiness checklist
- grain review before joins
- tests on key uniqueness and join assumptions
- explicit guidance on when full refresh is actually needed

### 3. warehouse spillage or memory pressure

This should be taught mainly as a diagnosis amplifier.

Likely causes:

- join explosion
- oversized all-in-one SQL
- repeated inlined logic
- a query too complex for the current compute size

Direct dbt optimizations:

- fix the actual modeling issue first
- split the logic into multiple models
- persist expensive intermediate results
- only discuss upsizing compute after query shape has been improved

Prevention themes:

- avoid giant single-model transformations
- review compiled query shape for heavily used models
- prefer architectural fixes before warehouse sizing changes

### 4. CI or deploy jobs are slow and expensive

Possible causes to demonstrate:

- selectors are too broad
- tests are selected too broadly
- the job rebuilds unchanged nodes
- CI has no state/deferral strategy
- expensive tests are running in every environment

Direct dbt optimizations:

- use `state:modified+`
- enable deferral / model reuse
- tune indirect test selection
- split jobs by purpose instead of one monolithic build job
- reserve heavyweight tests for deploy or scheduled quality checks

Prevention themes:

- standard job templates
- selector conventions
- environment-specific test policy
- review process for job changes

### 5. storage spend is creeping up

Possible causes to discuss:

- cloned objects living too long or diverging too much
- permanent tables used where transient is sufficient
- excessive rewrites of large tables
- unnecessary dev/staging persistence

Direct dbt or adjacent optimizations:

- configure transient objects appropriately by environment
- clean up dev/CI schemas aggressively
- reduce churn through better incremental patterns
- set expectations around clone lifecycle management

Prevention themes:

- environment-level conventions
- CI cleanup policies
- dev schema hygiene
- production-vs-development persistence strategy

## Additional dbt-focused optimization topics to include

These are important because they make the workshop more explicitly about dbt, not just about warehouses.

### Test suite cost

This should be treated as a first-class optimization topic.

Symptoms:

- jobs spend disproportionate time in tests
- warehouse spend is driven by heavy generic tests on large marts
- every PR validates far more than is necessary

dbt fixes:

- run critical, cheap tests in CI
- move heavyweight tests to deploy/nightly where appropriate
- tune indirect selection behavior
- use state-aware selection so tests only run where relevant
- avoid redundant tests across multiple layers

### Over-selection in DAG execution

Symptoms:

- a tiny code change triggers a large and expensive run
- the team routinely rebuilds and retests unaffected nodes

dbt fixes:

- use state-based selectors
- refine selector scope for deploy, CI, and backfill jobs
- separate validation jobs from broad production build jobs

### Ephemeral overuse and repeated inlined logic

Symptoms:

- compiled SQL becomes huge
- one downstream model becomes a monster query
- the same heavy transformation is recomputed multiple times

dbt fixes:

- persist expensive shared logic as a table or incremental model
- reserve `ephemeral` for lightweight composition logic
- introduce reusable intermediate models at the right grain

### Misplaced logic in marts

Symptoms:

- marts do source cleanup, fanout joins, and heavy transformation all at once
- difficult query profiles and brittle rebuilds

dbt fixes:

- move cleanup to staging
- move join and aggregation logic to intermediate
- keep marts focused on contracted presentation-ready outputs

## Priority order for the training

### Tier 1: must-have modules

These should get the most airtime.

1. `view` that should be a `table`
2. `table` that should be `incremental`
3. slim CI, state, and deferral
4. refactoring messy SQL into modular dbt models
5. test scope optimization

### Tier 2: strong supporting modules

6. unhealthy joins / row explosion
7. write amplification / churn
8. repeated heavy logic / ephemeral overuse
9. pruning and clustering candidate analysis

### Tier 3: bonus or shorter modules

10. storage optimization
11. clone hygiene
12. transient vs permanent table policy
13. warehouse spillage as a symptom amplifier

## What needs to be built in this repo

This section defines the intended artifact inventory for the workshop.

### A. model-level workshop examples

We need intentionally poor examples that can be diagnosed and then fixed.

#### A1. expensive `view` bottleneck

Need:

- one model materialized as a `view`
- the model should be queried frequently in the workshop story
- querying it should force repeated expensive logic every time

Fix to demonstrate:

- convert to `table`
- optionally introduce an upstream persisted intermediate if the logic is shared

Potential shape:

- a customer/order enrichment model
- a reporting-friendly mart built on multiple joins and calculations

#### A2. large `table` that should be `incremental`

Need:

- one fact-like model currently built as a full table rebuild
- seed-driven append data so workshop attendees can simulate new ingestion
- enough historical volume to make the rebuild story obvious

Fix to demonstrate:

- convert to `incremental`
- add a selective predicate
- optionally demonstrate late-arriving data or schema-change handling discussion

#### A3. large table with poor pruning / clustering candidate

Need:

- a physically large fact table or synthetic history table
- data distribution that makes pruning poor before optimization
- a realistic query pattern that filters on a small subset of columns

Fix to demonstrate:

- identify candidate key based on access pattern
- apply warehouse-specific physical design optimization
- discuss platform portability: same diagnosis pattern, different physical mechanism

#### A4. unhealthy join / row explosion model

Need:

- one model whose joins create fanout or duplicate amplification
- enough shape in the data to show a clear profile symptom
- a business grain mismatch that can be explained clearly

Fix to demonstrate:

- align grains before joining
- deduplicate upstream where appropriate
- split logic into intermediate models that make grain obvious
- add tests to protect uniqueness assumptions

#### A5. write amplification / churn example

Need:

- one model that rewrites too much unchanged data
- ideally an incremental candidate where the wrong strategy causes excessive merge/update work

Fix to demonstrate:

- change incremental strategy or filtering logic
- process changed keys only
- reduce full-table rewrites

#### A6. messy all-in-one SQL model refactor lab

Need:

- one deliberately ugly model with too many responsibilities
- nested CTEs, repeated logic, mixed grains, and poor readability
- enough complexity to justify splitting into two or three models

Fix to demonstrate:

- decompose into staging/intermediate/mart responsibilities
- persist reusable heavy steps where it helps
- show that better dbt architecture is also a cost optimization

This is a strong candidate for the main hands-on lab.

#### A7. expensive test selection example

Need:

- at least one model with heavyweight tests that are appropriate for scheduled/deploy but too expensive for every CI run
- a job config that currently tests too much

Fix to demonstrate:

- narrow test selection
- tune indirect selection
- move some tests to a different job cadence

### B. job-level workshop examples

We need intentionally inefficient jobs that can be audited and improved together.

#### B1. before-state deploy job

Need a deploy job that is intentionally too expensive in a plausible way:

- broad build selector
- broad test execution
- no state-based narrowing where appropriate
- no discussion-friendly decomposition of steps

After-state should demonstrate:

- purpose-built selectors
- cleaner separation between build and heavier validation if useful
- tighter commands that align with deployment intent

#### B2. before-state CI job

Need a CI job that is intentionally wasteful:

- builds too much of the DAG
- tests too much indirectly
- does not use slim CI concepts well
- does not handle new incremental models in PR schemas cleanly

After-state should demonstrate:

- `state:modified+`
- deferral/model reuse
- selective test execution
- optional schema cleanup operation for PR schemas when validating net-new incremental work

#### B3. state/model reuse demonstration job

Need a repeatable demo where the first run does substantial work and a second run benefits from state/model reuse.

This is more of a live demo than a broken-state exercise.

### C. storage examples / discussion assets

Need:

- clear talking points and maybe one or two environment configs that illustrate transient vs permanent behavior
- examples of why long-lived clones and churn matter
- dev/CI schema cleanup strategy as part of storage governance

This section may rely more on discussion and config review than on heavy repo changes.

## Expected answer key usage

For each major workshop exercise, decide whether the optimized end state should exist as:

1. a corrected version under `models/answer_key/`
2. a branch or commit checkpoint used by the instructor
3. both

Recommended default:

- use `models/answer_key/` for model-level optimized SQL and YAML
- use saved job definitions in dbt for job-level before/after comparison
- use instructor notes for storage topics that are partly external to dbt

## Proposed workshop sections

### Section 1. Intro: cost optimization through dbt

Goal:

- establish that dbt decisions shape both runtime and bytes scanned/read
- introduce the three optimization layers: model, job, storage

### Section 2. Materialization strategy

Examples:

- expensive view that should be table
- large table that should be incremental

Outcome:

- attendees learn when model persistence changes query cost materially

### Section 3. Query shape and model architecture

Examples:

- unhealthy join / exploding join
- messy all-in-one SQL refactor
- repeated inlined logic / ephemeral overuse if included

Outcome:

- attendees learn that DAG design is query optimization

### Section 4. Reading less data

Examples:

- pruning/clustering candidate
- incremental filters
- reducing redundant tests or broad selectors

Outcome:

- attendees learn how dbt choices influence scan volume directly

### Section 5. Job optimization

Examples:

- audit a bad deploy job
- audit a bad CI job
- demonstrate state + deferral + indirect test selection

Outcome:

- attendees learn how to stop rebuilding and retesting the world

### Section 6. Storage and environment hygiene

Examples:

- transient vs permanent
- clone awareness
- schema cleanup
- write amplification as a storage and compute concern

Outcome:

- attendees understand that cost optimization is not just query runtime

## Questions to answer next in project planning

After this plan is accepted, the next design pass should answer these concretely:

1. which existing models should be edited to become each workshop example
2. which examples need net-new models or synthetic history tables
3. which seed files are needed for incremental ingestion demos
4. what the exact `answer_key/` footprint should be
5. how many dbt jobs need to exist for the workshop
6. the exact before-state and after-state job commands/selectors
7. which modules are demo-only vs attendee hands-on
8. which prevention controls should be emphasized for each module

## Initial recommendations for the next planning step

When mapping this into the actual repo, prefer:

- reusing existing marts/facts for the materialization and incremental modules where possible
- creating one intentionally bad refactor lab model rather than making every model messy
- using job configuration as the main teaching surface for state/deferral/test scope topics
- keeping clustering/pruning and storage as focused examples rather than the center of the workshop

## Success criteria for this repo update

This training project is ready when:

- each major symptom has a concrete example in the repo or in dbt job configuration
- the bad state is plausible and easy to diagnose
- the good state has a clear answer key
- each module has a prevention takeaway, not just a one-time fix
- the examples together demonstrate both faster queries and less data read


## Proposed mapping: existing models to workshop sections

This section maps the current project assets to the intended workshop modules. The assumption is that we are free to intentionally worsen the existing models so the repo contains realistic bad states for diagnosis and repair.

The goal is not to make every model bad. The goal is to create a small number of clear, high-signal anti-patterns that each support one specific teaching outcome.

### Recommended existing-model anchors

#### 1. `dim_wizards` as the `view` that should be a `table`

Use:

- `models/marts/dim_wizards.sql`

Why this is a strong fit:

- dimension-shaped and easy to explain as a frequently queried BI surface
- already joins customer records to current membership state
- plausible candidate for repeated expensive recomputation if materialized incorrectly

Planned bad state:

- override materialization to `view`
- optionally make the upstream membership enrichment slightly more expensive so the cost of recomputation is visible
- optionally add a small amount of derived classification logic directly in the mart to reinforce the point that frequently queried marts should not stay virtual forever

Fix to demonstrate:

- change `view` to `table`
- optionally move any repeated heavy logic into a reusable persisted upstream model if we want to show a second-order improvement later in the workshop

Teaching notes:

- this is a high-impact / low-effort fix
- this should likely be one of the first hands-on or live demo modules
- lower-priority follow-on improvements can be revisited later if we want to discuss reuse or query shape

#### 2. `fct_orders` as the `table` that should be `incremental`

Use:

- `models/marts/fct_orders.sql`

Why this is a strong fit:

- naturally fact-like
- already includes `ordered_at`, which gives us a clean time-based entry point for incremental logic
- depends on upstream order and payment rollups, so the cost of full rebuilds is easy to make credible

Planned bad state:

- keep it as a full `table`
- increase historical volume in the upstream seed data so full rebuilds are obviously wasteful
- optionally introduce update patterns such as refunds or late-arriving payment changes to make a naive incremental strategy incomplete

Fix to demonstrate:

- convert `table` to `incremental`
- add a selective incremental predicate
- discuss and then improve the logic so it does not miss updates to previously seen order IDs

Data/demo requirements:

- enlarge the base seed-backed history enough to make the full rebuild story visible
- create one or more reusable incremental demo seed sets that can be dropped in between trainings and re-added to simulate new ingestion
- include at least a few records that test whether the incremental logic properly captures changed historical orders, not just brand-new order IDs

Teaching notes:

- this should be paired immediately with a follow-on write amplification / churn discussion while incremental logic is still fresh in attendees’ minds
- this is one of the highest-priority modules in the workshop

#### 3. `int_orders_with_payments` as the unhealthy join / exploding join example

Use:

- `models/intermediate/int_orders_with_payments.sql`

Why this is a strong fit:

- it already sits at the intersection of order grain, line-item grain, and payment-attempt grain
- it is the most natural place in the current DAG to intentionally violate grain discipline
- the current model is written in the correct style, so it gives us a clean before/after narrative

Planned bad state:

- replace the current safe pre-aggregation pattern with a raw join across `orders`, `order_items`, and `payments`
- aggregate only after the fanout has occurred
- let the row explosion show up both in runtime/cost and in incorrect business results

Fix to demonstrate:

- aggregate line items to `order_id`
- aggregate payments to `order_id`
- join those rollups back to the order-grain input
- use intermediate model structure and tests to make grain explicit and protected

Teaching notes:

- this is a very strong before/after walk-through module
- it supports both performance optimization and correctness optimization, which makes it especially useful in training

#### 4. `fct_order_items` as the pruning / clustering candidate

Use:

- `models/marts/fct_order_items.sql`

Why this is a strong fit:

- line-grain fact tables are naturally larger than order-grain facts
- realistic access patterns already exist around `ordered_date`, `shop_id`, and `potion_sku`
- this model is not currently needed for another major performance demo, so it can stay focused on pruning and physical optimization

Planned bad state:

- enlarge the underlying history substantially so the scans are meaningful
- leave the physical layout unhelpful for the query patterns we plan to demonstrate
- create repeated query patterns on top of the model so we have a clear basis for identifying common filter/join columns

Fix to demonstrate:

- analyze the query pattern and identify the right clustering candidate for the demonstrated workload
- apply the clustering optimization at the table that directly benefits from the access pattern
- reinforce that the cross-platform lesson is pruning/data skipping, even though the implementation is Snowflake-specific in this workshop

Open design question to preserve in planning:

- in general, it is better to optimize the table that directly serves the workload you care about, not cluster everything upstream by default
- if a shared upstream table is the actual repeatedly queried surface, optimize there; if a downstream fact is the real hotspot, optimize the downstream fact
- for this workshop, `fct_order_items` is a good focused target because we can tie the optimization directly to observed query patterns against that model

Data/demo requirements:

- balloon the row count materially
- build a lightweight sample “gold layer” or dashboard-like workload on top of `fct_order_items`, likely with two or three reporting views/queries that can be scheduled or run repeatedly
- use those repeated queries to generate the workload evidence needed to identify likely clustering columns during the demo

Teaching notes:

- this should be framed as a later-stage optimization after architecture and materialization are already in reasonable shape
- the lesson is not “always cluster”; the lesson is “optimize physical layout when query patterns justify it”

#### 5. `fct_orders` follow-on for write amplification / churn

Use:

- `models/marts/fct_orders.sql`

Why this is a strong fit:

- it naturally extends the incremental materialization module
- the same fact can show the progression from full rebuild, to naive incremental, to better incremental logic with less churn

Planned bad state:

- use an incremental strategy that rewrites too much unchanged data or scans too much history
- include changes such as refunds or late-arriving payment events that make naive logic either incomplete or unnecessarily expensive

Fix to demonstrate:

- tighten the scope of changed rows
- process changed order IDs only, or use another bounded strategy that materially reduces unnecessary rewrite behavior
- show that “incremental” alone is not the finish line; the change-detection logic matters

Teaching notes:

- this should sit immediately after the initial incremental example
- attendees will already have the context needed to understand why churn matters

### Recommended net-new models

#### 6. One intentionally gross mart for the modular refactor lab

Recommendation:

- create one net-new mart model specifically for the messy SQL refactor exercise

Reason to make this net-new instead of overloading an existing mart:

- we want one model that is spectacularly bad in a deliberate, teachable way
- keeping it separate prevents `fct_orders` from becoming the example for every anti-pattern at once
- a dedicated refactor lab model gives us flexibility to make it ugly enough to be worth decomposing into multiple dbt models

Desired bad-state characteristics:

- too many responsibilities in one model
- nested CTEs
- repeated logic
- mixed grains
- hard-to-follow calculations
- poor separation between cleanup, joining, and final presentation logic

Desired refactor path:

- one or two intermediate models with explicit grains and responsibilities
- one final mart that presents the output cleanly
- enough structure that we can either refactor together by hand or, if time is tight, use Wizard to accelerate the decomposition

Possible candidate names:

- `models/marts/fct_wizard_order_behavior.sql`
- `models/marts/fct_commercial_performance.sql`
- `models/marts/fct_order_profitability_report.sql`

Answer key expectation:

- the cleaned-up end state for this exercise should live under `models/answer_key/intermediate/` and `models/answer_key/marts/`

Teaching notes:

- this is a strong candidate for the main hands-on lab
- this module also doubles as a good place to show how dbt architecture itself is a cost optimization

#### 7. Optional future module: expensive shared ephemeral logic

Recommendation:

- keep this in the backlog for now
- only build it out if time allows after the core modules are in place

Reason:

- it is a good dbt-specific lesson
- it is lower immediate priority than materialization, incrementals, joins, job scope, and the modular refactor lab

Potential shape if built:

- one expensive shared intermediate model used by multiple downstream consumers
- intentionally materialized as `ephemeral`
- later converted to a persisted reusable model

Current disposition:

- cover in slides either way
- decide later whether to add a full hands-on/demo implementation

## Seed and data planning

### Existing seed inventory

The project already has the base seed structure we need under `seeds/medium_data/`, including:

- `abra_pos/raw_orders.csv`
- `abra_pos/raw_order_items.csv`
- `abra_pos/raw_payments.csv`
- `abra_pos/raw_potions.csv`
- `grimoire_crm/raw_customers.csv`
- `grimoire_crm/raw_guild_memberships.csv`
- `grimoire_crm/raw_guilds.csv`
- `alembic_ops/raw_shops.csv`
- plus the procurement-lab seed assets

This is a good base for both model-level and job-level training examples.

### Additional seed work required

#### For the incremental / churn demo

We should create reusable seed sets that let us simulate incremental ingestion during the workshop.

Need:

- a larger base history for orders, order items, and payments
- one or more “drop in” incremental batches for repeatable live demos
- records that represent both:
  - brand-new orders
  - updates or late-arriving events that affect existing order IDs

Goal:

- demonstrate the cost difference between full rebuild and incremental build
- validate that the incremental logic both improves performance and captures the right business changes

#### For the pruning / clustering demo

We should materially increase the size of the line-grain history behind `fct_order_items`.

Need:

- enough additional order-item history to make repeated scans nontrivial
- realistic distributions across dates, shops, and potion SKUs
- a repeated query workload that can be used to derive likely pruning/clustering candidates from observed usage

## Tests and jobs planning

### Existing mart YAML as the test surface

The current mart YAML already provides a solid base of realistic tests:

- PK `unique` + `not_null`
- FK `relationships`
- `accepted_values`
- semantic-model metadata on fact models

This is useful because we do not need to invent the idea of tests from scratch. We can instead make the cost problem about how broadly and how frequently they are selected and run.

### Heavyweight test-scope example

Planned training behavior:

- add heavyweight tests that are plausible and useful, but too expensive to run in every CI job and against every changed node indiscriminately
- configure jobs so those tests are initially selected too broadly
- then show how to refine selectors and indirect test behavior

Teaching goal:

- move from “test everything all the time” to “run the right tests at the right cadence and environment”

## PR schema cleanup macro

The project now includes the PR schema cleanup macro at:

- `macros/utils/reset_pr_schemas.sql`

Summary of its role in the workshop:

- this is best positioned as a CI workflow quality-of-life and operability improvement
- it is especially useful when validating net-new incremental models in PR schemas
- it helps prevent manual intervention when stale PR-schema objects cause incremental validation problems

How it fits in the job section:

- include it as the first command in the optimized CI job design when that workflow is being discussed
- position it as part of the “prevent repeated CI friction” story more than as a primary warehouse-cost optimization on its own

## Recommended before-state jobs

Create three job examples for the workshop.

### 1. before-state deploy job

Purpose:

- audit and improve a plausible but overly expensive deploy workflow

Bad-state characteristics:

- broad build selector
- broad test execution
- job commands are more monolithic than they need to be
- no deliberate distinction between core deployment validation and heavier quality checks

After-state should demonstrate:

- purpose-built selectors
- cleaner alignment between job purpose and commands
- optional separation between deploy-critical validation and heavier scheduled validation

### 2. before-state CI job

Purpose:

- audit and improve a wasteful CI workflow

Bad-state characteristics:

- builds too much of the DAG
- tests too much indirectly
- does not use slim CI/state concepts effectively
- does not handle net-new incremental validation in PR schemas gracefully

After-state should demonstrate:

- `state:modified+`
- deferral/model reuse
- more selective indirect test execution
- `reset_pr_schemas` as the first command when appropriate for incremental PR-schema cleanup

### 3. state/model reuse demonstration job

Purpose:

- provide a repeatable live demo where the first run does substantive work and the second run shows the benefit of state/model reuse

Notes:

- this is more of a demonstration job than a broken-state exercise
- it should be simple enough to rerun quickly during training

## Proposed implementation matrix

This is the working recommendation for what we should build first.

| Training module | Primary asset | Reuse existing or net-new | Planned bad state | Planned fix |
|---|---|---|---|---|
| View that should be table | `models/marts/dim_wizards.sql` | Existing | Materialize as `view`, optionally add slightly expensive enrichment | Convert to `table`, optionally persist shared logic upstream |
| Table that should be incremental | `models/marts/fct_orders.sql` | Existing | Full rebuild table over larger history | Convert to `incremental` with selective predicate |
| Incremental churn / write amplification | `models/marts/fct_orders.sql` | Existing | Naive incremental logic that scans/rewrites too much or misses changed rows | Tighten changed-row logic |
| Unhealthy / exploding join | `models/intermediate/int_orders_with_payments.sql` | Existing | Join order, line, and payment grains before aggregating | Pre-aggregate to `order_id` and then join |
| Pruning / clustering candidate | `models/marts/fct_order_items.sql` | Existing | Larger fact with poor physical layout for repeated query patterns | Identify candidate and apply clustering |
| Messy SQL refactor lab | New mart + 1–2 new intermediates | Net-new | One giant multi-responsibility model | Split into explicit-grain intermediates and a cleaner mart |
| Expensive test scope | Existing marts + jobs | Existing + job config | Heavy tests selected too broadly in CI/deploy | Narrow selectors and tune indirect test selection |
| CI optimization | CI job | Net-new job config | Broad builds/tests, no cleanup, weak state usage | Slim CI, deferral, state, targeted tests |
| Deploy optimization | Deploy job | Net-new job config | Overly broad deploy commands | Purpose-built deploy commands |
| State/model reuse demo | Reuse demo job | Net-new job config | Demo-oriented baseline | Show benefit of repeated run with reuse |

## Questions preserved for the next build pass

The next implementation-planning pass should answer these concretely:

1. exactly how much additional seed volume we need for `fct_orders` and `fct_order_items`
2. the exact filenames and format for reusable incremental demo batches
3. whether the pruning demo uses dashboard-like views, saved queries, or both
4. the exact bad SQL shape and business output for the net-new refactor lab model
5. which tests should be made intentionally heavyweight for the job optimization section
6. the exact before-state and after-state commands/selectors for the three workshop jobs


## Repo implementation checklist

This section turns the workshop plan into a concrete build matrix for the repo.

The intent is to answer four questions:

1. which existing files should be intentionally worsened
2. which net-new files should be created
3. which seed artifacts should be added for repeatable demos
4. what the before-state and after-state jobs should run

## 1. Existing files to modify intentionally

### A. `models/marts/dim_wizards.sql`

Role in workshop:

- model-level optimization
- `view` that should be a `table`

Current state:

- simple customer dimension with current guild enrichment
- good candidate for a frequently queried dimensional surface

Planned bad-state edits:

- override materialization to `view`
- optionally add a few extra derived classifications directly into the mart so every downstream query recomputes them
- optionally make the upstream current-membership enrichment slightly more expensive if we want the performance pain to be more obvious

Planned optimized end state:

- materialize as `table`
- keep only the logic that belongs in the mart
- optionally persist any reused heavy enrichment upstream

Likely related files:

- `models/marts/_marts.yml`
- possibly `models/intermediate/int_memberships_current.sql` if we decide to add a secondary optimization layer
- answer-key counterpart under `models/answer_key/marts/`

### B. `models/marts/fct_orders.sql`

Role in workshop:

- model-level optimization
- `table` that should be `incremental`
- write amplification / data churn follow-on

Current state:

- order-grain fact with timestamps and payment-related measures/flags
- strongest existing anchor for the incremental lesson

Planned bad-state edits:

- leave as full rebuild `table`
- scale up history so full rebuilds are costly enough to be obvious
- when transitioning into the churn module, implement a deliberately naive incremental strategy before showing the improved version

Planned optimized end state:

- convert to `incremental`
- implement a selective incremental predicate
- iterate to a more robust change-detection strategy so updates to existing orders are handled correctly without excessive churn

Likely related files:

- `models/marts/_marts.yml`
- `models/intermediate/int_orders_with_payments.sql`
- answer-key counterpart under `models/answer_key/marts/`

### C. `models/intermediate/int_orders_with_payments.sql`

Role in workshop:

- query shape optimization
- unhealthy join / exploding join example

Current state:

- correctly aggregates line items and payments to order grain before joining back to orders
- ideal starting point for a clear before/after transformation

Planned bad-state edits:

- replace the current safe structure with a direct join between `orders`, `order_items`, and `payments`
- aggregate only after the fanout has already happened
- let both the row explosion and the incorrect business metrics become visible

Planned optimized end state:

- restore explicit grain alignment
- aggregate line items to `order_id`
- aggregate payments to `order_id`
- join those rollups back to orders

Likely related files:

- `models/marts/fct_orders.sql`
- possibly tests in `models/marts/_marts.yml` if we want to emphasize protections on downstream facts
- answer-key counterpart under `models/answer_key/intermediate/`

### D. `models/marts/fct_order_items.sql`

Role in workshop:

- physical optimization / read-less-data example
- pruning and clustering candidate

Current state:

- line-grain fact with natural filter dimensions including `ordered_date`, `shop_id`, and `potion_sku`

Planned bad-state edits:

- leave physical layout unoptimized for expected access patterns
- scale row volume materially via larger seed history
- potentially add one or two common downstream reporting surfaces that repeatedly query it in the same way

Planned optimized end state:

- apply clustering or equivalent physical optimization at the table that directly serves the demonstrated workload
- keep the demo focused on query-pattern-driven optimization, not blanket clustering guidance

Likely related files:

- `models/marts/_marts.yml`
- new reporting/demo models or analysis queries that exercise `fct_order_items`
- answer-key counterpart under `models/answer_key/marts/` if we want the optimized clustering config documented there

### E. `models/marts/_marts.yml`

Role in workshop:

- test-scope cost optimization
- contracts/tests documentation for answer key and hands-on comparisons

Current state:

- already contains realistic PK, FK, accepted-values, and semantic metadata

Planned bad-state edits:

- keep the current useful tests
- add a small number of heavier tests that are realistic but too expensive to run indiscriminately in every CI and deploy job
- make the job configs initially select them too broadly

Planned optimized end state:

- keep the tests, but tune when and how they are selected
- potentially tag or otherwise distinguish some heavier tests for deploy/nightly cadence discussions

Likely related files:

- job definitions in dbt
- any additional generic or singular tests added under `tests/`
- answer-key YAML if we want an explicit “ideal selection strategy” note in comments/docs

## 2. Net-new files to create

### A. Main hands-on lab: one intentionally gross mart

Recommendation:

- create one net-new mart and one or two supporting intermediate models

Suggested naming direction:

- mart: `models/marts/fct_wizard_order_behavior.sql`
- intermediates:
  - `models/intermediate/int_wizard_order_behavior_base.sql`
  - `models/intermediate/int_wizard_order_behavior_segments.sql`

Alternative names are fine; the important part is the shape, not the label.

Desired bad-state characteristics of the mart:

- one giant file
- nested CTEs
- repeated joins/calculations
- mixed grains
- customer, order, payment, and potion logic all mashed together
- hard to reason about and expensive to execute

Desired optimized end state:

- split the model into one or two explicit-grain intermediate models
- keep the final mart presentational and contract-friendly

Files to add for the bad state:

- `models/marts/<chosen_lab_model>.sql`
- `models/marts/<chosen_lab_model>.yml` or updates in `models/marts/_marts.yml` depending on repo preference

Files to add for the answer key:

- `models/answer_key/intermediate/<chosen_int_model_1>.sql`
- `models/answer_key/intermediate/<chosen_int_model_2>.sql` if needed
- `models/answer_key/marts/<chosen_lab_model>.sql`
- answer-key YAML/doc assets if useful for side-by-side comparison

### B. Optional reporting/demo surfaces for the clustering module

Recommendation:

- add two or three lightweight reporting-facing demo models, views, or saved queries that repeatedly hit `fct_order_items`

Preferred repo-first option:

- create analysis files or lightweight demo models rather than overcomplicating the core marts

Possible paths:

- `analyses/order_items_perf__shop_daily.sql`
- `analyses/order_items_perf__category_trend.sql`
- `analyses/order_items_perf__sku_region.sql`

Reason:

- these give us repeatable query patterns for the pruning/clustering section
- they also create a realistic story for identifying common filter/join columns

### C. Optional future module for expensive shared ephemeral logic

Only if time allows later:

- one expensive shared intermediate model used by multiple downstream models
- answer-key version materialized more appropriately

This stays in backlog for now.

## 3. Seed artifacts to add

The current raw commerce seeds under `seeds/medium_data/abra_pos/` are the right foundation. We should expand them with repeatable training-oriented variants.

### A. Larger base-history seeds

Goal:

- make `fct_orders` and `fct_order_items` large enough to create visible differences in runtime and scanned data

Recommended approach:

- generate larger versions of:
  - `raw_orders.csv`
  - `raw_order_items.csv`
  - `raw_payments.csv`
- preserve the same schema and business shape
- increase row counts through repeated time windows, new IDs, and realistic distributions

Implementation note:

- simplest path is likely to regenerate the existing seed data with more history and more records per day while keeping the seed filenames stable
- if we want to preserve the smaller dataset for local onboarding, create a separate training dataset plan and document how to swap between them

### B. Incremental demo batch artifacts

Goal:

- support a repeatable live demo where new data appears after the base build
- allow the trainer to reset between sessions

Recommended artifacts:

- one or more batch files representing a new ingest window for:
  - orders
  - order items
  - payments
- one or more batch files representing late-arriving updates for existing order IDs, especially payment/refund changes

Suggested naming direction:

- `docs/demo_data/incremental_batch_01_notes.md` for instructions
- raw data files stored under a dedicated training path such as:
  - `seeds/training_batches/abra_pos/raw_orders__batch_01.csv`
  - `seeds/training_batches/abra_pos/raw_order_items__batch_01.csv`
  - `seeds/training_batches/abra_pos/raw_payments__batch_01.csv`
  - `seeds/training_batches/abra_pos/raw_payments__late_updates_01.csv`

Important note:

- these do not necessarily need to be included in `seed-paths` permanently
- they can exist as training assets with documented steps for copying/swapping them into the active seed set before a demo

### C. Pruning/clustering workload support

Goal:

- make `fct_order_items` large enough and busy enough to justify a physical optimization discussion

Recommended approach:

- bias the larger history so common access dimensions are realistic and repeated
- keep filterable columns like `ordered_date`, `shop_id`, and `potion_sku` well represented
- if category-oriented workload is important, ensure potion distributions make those queries interesting too

## 4. File-by-file build order

Recommended implementation order for the repo build-out:

### Phase 1: highest-priority workshop assets

1. enlarge the commerce seed history
2. implement the bad-state version of `fct_orders`
3. implement the bad-state version of `int_orders_with_payments`
4. implement the bad-state version of `dim_wizards`
5. create the net-new messy refactor lab model
6. add answer-key counterparts for those four modules

### Phase 2: supporting optimization assets

7. expand `fct_order_items` demo volume
8. add reporting/demo query surfaces for clustering analysis
9. add heavier tests and document how jobs select them
10. create any answer-key assets needed for clustering/test-selection sections

### Phase 3: optional backlog assets

11. add the expensive shared-ephemeral module if time allows
12. add any extra storage-policy examples if desired

## 5. Draft job inventory and commands

These are the recommended workshop jobs. The exact environment IDs and UI settings will be configured in dbt, but we should document the intended command shape now.

### Job 1: before-state CI job

Purpose:

- intentionally wasteful CI example for audit and optimization

Suggested bad-state commands:

```text
dbt build --select +fct_orders+
dbt build --select +fct_order_items+
dbt build --select +dim_wizards+
```

Why this is bad:

- broad, repetitive DAG execution
- too much indirect test execution
- no state awareness
- no reuse/deferral strategy
- no handling for stale incremental objects in PR schemas

Suggested optimized commands:

```text
dbt run-operation reset_pr_schemas

dbt build --select state:modified+ --indirect-selection cautious

dbt build --select state:modified+,config.materialized:incremental --indirect-selection cautious
```

Notes:

- keep this aligned with your PR-schema cleanup pattern for net-new incremental models
- in the dbt job config, pair this with state/deferral settings so the selection strategy actually behaves like slim CI
- exact selector syntax may be tuned once the final model set for the workshop is in place

### Job 2: before-state deploy job

Purpose:

- intentionally broad deploy example

Suggested bad-state commands:

```text
dbt build --select +fct_orders+
dbt build --select +fct_order_items+
dbt build --select +fct_payments+
dbt build --select +dim_wizards+
```

Alternative simpler bad state:

```text
dbt build
```

Why this is bad:

- deploy job scope is broader than necessary
- tests run at the same cadence as core deployment work even when some are better suited to scheduled validation
- commands are not aligned tightly with deployment intent

Suggested optimized commands:

```text
dbt build --select state:modified+
```

Optional after-state variant if you want deploy-vs-validation decomposition:

```text
dbt build --select state:modified+
dbt test --select state:modified+ --indirect-selection cautious
```

Notes:

- whether to use one or two commands depends on how explicitly you want to teach separation of concerns in jobs
- if the workshop should emphasize that deploys and broad-quality sweeps are different concerns, split them

### Job 3: state/model reuse demo job

Purpose:

- run the same job twice and compare work done across runs

Suggested baseline commands:

```text
dbt build --select fct_orders+
```

Suggested variant if you want a broader demo surface:

```text
dbt build --select fct_orders+ fct_order_items+
```

Notes:

- the point here is not a broken selector, it is observability
- use whichever surface best shows measurable improvement once state/model reuse is enabled in the job configuration
- this job should stay simple enough to rerun live without a lot of setup friction

## 6. Draft answer-key footprint

Recommended answer-key additions beyond the existing procurement lab assets:

### Existing-model answer keys

- `models/answer_key/marts/dim_wizards.sql`
- `models/answer_key/marts/fct_orders.sql`
- `models/answer_key/marts/fct_order_items.sql` if we want the optimized clustering config represented explicitly
- `models/answer_key/intermediate/int_orders_with_payments.sql`

### Net-new lab answer keys

- `models/answer_key/intermediate/<lab_intermediate_1>.sql`
- `models/answer_key/intermediate/<lab_intermediate_2>.sql` if needed
- `models/answer_key/marts/<lab_mart>.sql`

### YAML / docs answer-key support

Depending on how explicit we want the side-by-side comparison to be, we may also want:

- answer-key YAML snippets or files for any changed contracts/tests/configs
- a short `models/answer_key/README.md` update explaining which files correspond to which training modules

## 7. Recommended concrete next implementation tasks

This is the suggested execution queue for actually building the gnarly workshop repo.

1. decide the final name and business shape of the messy refactor lab model
2. generate larger base seed data for orders, order items, and payments
3. generate one reusable incremental batch and one reusable late-update batch
4. worsen `int_orders_with_payments` into the join-explosion version
5. worsen `fct_orders` into the full-table / naive-incremental teaching surface
6. worsen `dim_wizards` into the view bottleneck
7. add the clustering workload support around `fct_order_items`
8. add heavier tests that are useful but too broad for default CI
9. create the three job definitions in dbt
10. add answer-key versions for each major model exercise

## 8. Validation strategy while we build this out

As we implement the workshop repo, validate each module individually:

- use `dbt build --select +<model>+` after each model-level change
- validate the messy refactor lab both in bad-state and answer-key form
- validate seed swaps and incremental demo flow end to end before the workshop
- validate each job definition independently so the job section is reproducible live

Success means:

- each example fails or performs poorly for the intended reason
- the fix is clear and demonstrable
- the answer key is structurally cleaner than the bad state
- the training can be reset between sessions without manual heroics


## Final decision: messy refactor lab model

The net-new messy refactor lab model is now decided.

### Chosen lab model

Use:

- `models/marts/fct_wizard_order_behavior.sql`

Reason this is the winner:

- it stays within a single business story: customer/order behavior
- it avoids crossing into other domains such as procurement, which would dilute the teaching focus
- it is realistic as a rushed “one-stop analytics mart” that teams often create under deadline pressure
- it supports a clean symptom-to-optimization mapping for the workshop

This is important for the training design. Even though real projects often contain models with multiple overlapping issues, this workshop should keep each hands-on example focused enough that attendees can clearly connect the symptom they see to the dbt optimization being applied.

### Intended business purpose

`fct_wizard_order_behavior` should represent a customer behavior mart used for commercial or lifecycle analysis.

Example question types it should support:

- how often does each wizard order
- how much has each wizard spent over time
- what potion categories does each wizard prefer
- which customers are guild members and how does that affect behavior
- which customers show refund or split-payment behavior
- which channels does each customer use most often

### Intended grain

The final intended grain should be:

- one row per `customer_id`

This makes the refactor more teachable because the bad-state version can be sloppy about how that grain is achieved, while the answer-key version makes the grain explicit through modular design.

### Planned bad-state characteristics

The bad-state `fct_wizard_order_behavior` model should intentionally be a giant, multi-responsibility mart with characteristics like:

- one oversized SQL file
- nested CTEs
- repeated joins and repeated calculations
- customer, order, payment, and potion logic all combined in one place
- mixed grains handled inline rather than explicitly
- category logic and payment logic embedded directly in the mart
- difficult-to-follow calculations and weak separation of concerns

The goal is to create a model that is:

- expensive to execute
- hard to reason about
- awkward to validate
- clearly a candidate to be split into multiple dbt models

### Refactored answer-key shape

The optimized end state should live in `models/answer_key/` and should be split into:

#### 1. `models/answer_key/intermediate/int_wizard_order_behavior_base.sql`

Purpose:

- customer-grain behavioral rollup based on orders and payments

Expected contents:

- lifetime order count
- lifetime net revenue
- average order value
- latest order date
- refund and split-payment behavior summaries
- channel usage summaries as appropriate

#### 2. `models/answer_key/intermediate/int_wizard_potion_preferences.sql`

Purpose:

- customer-grain preference rollup based on line items and potion attributes

Expected contents:

- total units purchased
- favorite potion category
- regulated-potion behavior flags or counts
- estimated total supply cost rolled up from `int_potion_supply_cost`
- high-cost potion line counts or similar light cost-aware preference features


#### 3. `models/answer_key/marts/fct_wizard_order_behavior.sql`

Purpose:

- final presentation-ready customer behavior mart

Expected contents:

- joins the two customer-grain intermediates
- joins in customer and guild attributes as needed
- keeps the final mart focused on presentation and governed output, rather than redoing all transformation logic inline

### Documentation expectation for the answer key

The answer-key version of this lab should include model documentation that explains:

- why the original model was too broad and too expensive
- how the grain was clarified during the refactor
- why the logic was split into these specific intermediate models
- what responsibilities belong in each intermediate versus the final mart
- how the refactor improves both maintainability and cost/performance

This documentation can live in standard dbt YAML descriptions and, if helpful, a short supporting note in `models/answer_key/README.md`.

### Workshop usage notes

This lab should support two facilitation modes:

1. **refactor by hand together** if time allows
2. **use Wizard to assist with decomposition** if the session is moving quickly or the focus is more on workflow than typing

Either way, the target shape should remain the same:

- 2 intermediate models with explicit responsibilities and grain
- 1 final mart at customer grain

### Output themes for the lab model

The model should expose a believable set of customer behavior fields, likely including some combination of:

- customer identity and profile attributes
- guild or membership attributes
- first/latest order dates
- days since last order
- lifetime order count
- lifetime net revenue
- average order value
- total units purchased
- favorite potion category
- regulated potion purchase behavior
- refund-related behavior
- split-payment behavior
- channel mix or counts

The exact column list can be finalized during implementation, but it should be rich enough to justify the split into the two intermediate models above.


## Documentation standard for every workshop artifact

To keep the training aligned, reproducible, and inheritable, every model-level demo should be treated as a complete artifact set rather than just a SQL change.

### Required deliverables for every model demo

For each intentionally bad example we build in `models/`:

1. **before-state model** in the main project DAG
   - under `models/marts/` or `models/intermediate/` as appropriate
2. **optimized after-state model** in `models/answer_key/`
   - using the same business purpose with improved design/configuration
3. **companion markdown documentation** for that model
   - named `<model_name>.md`
   - explaining the symptom, fix, reasoning, expected benefit, and comparison workflow

This applies to every major demo model, including but not limited to:

- `dim_wizards`
- `fct_orders`
- `int_orders_with_payments`
- `fct_order_items` if used for the clustering module
- `fct_wizard_order_behavior`
- any future optional demo models added later

### Required contents of each `<model_name>.md`

Each companion markdown file should document:

- what the symptom is
- what the root cause is
- how the issue was identified
- what dbt optimization was applied
- why that fix was the right one
- how the fix was implemented
- what the expected benefit is
- how to compare the before-state and after-state versions in the workshop
- what prevention or governance lesson should be carried forward

These files are part of the training deliverable, not optional extras. They will help:

- align the repo to the slide deck and live narration
- support handoff to a co-trainer
- support substitution if another presenter has to step in
- preserve the rationale behind the answer-key implementations

### Required job documentation

The jobs section should follow the same principle.

Need:

- before-state job definitions in dbt
- after-state job definitions or updated configurations in dbt
- one `jobs.md` document that explains:
  - the purpose of each job
  - the bad-state configuration/commands
  - the optimized configuration/commands
  - what symptom the job design creates
  - what changed and why
  - what the expected runtime/cost/operability improvement is
  - how to compare the before and after job behavior during training

Recommended location:

- `docs/jobs.md`

## Next build phase: data foundation

The next implementation step is to build the data foundation that supports the major demos.

### Current baseline

The current commerce seed files are now stored in the large training dataset and provide a solid foundation for the cost optimization workshop:

- `seeds/large_data/abra_pos/raw_orders.csv` is ~75k rows
- `seeds/large_data/abra_pos/raw_order_items.csv` is ~253k rows
- `seeds/large_data/abra_pos/raw_payments.csv` is ~86k rows

This is now a good base size for the workshop. It is large enough to make the optimization stories believable without making setup and reset unnecessarily heavy.

### Data-foundation goals

The expanded training data should support all of the following:

1. a visibly more expensive full rebuild of `fct_orders`
2. a meaningful incremental build improvement on `fct_orders`
3. a realistic late-arriving update pattern for the churn/write-amplification lesson
4. a materially larger `fct_order_items` fact for the pruning/clustering lesson
5. enough row volume that the messy refactor lab also feels plausibly expensive

### Recommended data-foundation strategy

#### 1. Use `seeds/large_data/` as the stable base dataset

The stable workshop seed foundation should remain in:

- `seeds/large_data/abra_pos/raw_orders.csv`
- `seeds/large_data/abra_pos/raw_order_items.csv`
- `seeds/large_data/abra_pos/raw_payments.csv`

Recommended characteristics of the base history:

- enough dates and row volume to make the cost and runtime stories believable
- realistic distributions by shop, channel, and potion SKU
- enough split payments, failed attempts, and refunds to support both join-health and incremental-update lessons

Guiding principle:

- keep the same semantic shape the models already expect
- make the data larger and more varied, not structurally different

#### 2. Use trainer-run Snowflake DML scripts for incremental demo events

For the workshop, attendees do not need to seed or reseed batch files themselves. They will build into their own schemas against trainer-managed shared source data.

That means the cleanest approach is:

- keep `seeds/large_data/` as the stable source-data baseline
- have trainers apply new source records directly in Snowflake before attendees trigger their rebuilds
- use those source changes to drive the incremental and churn demos

This more closely matches the real workflow we want to teach:

1. source data changes upstream
2. downstream dbt models rebuild in user schemas
3. incremental logic determines what gets processed

#### 3. Store trainer-run Snowflake scripts in `training_assets/snowflake_scripts/`

Recommended training asset location:

- `training_assets/snowflake_scripts/`

Required scripts:

- `01_append_orders_batch.sql`
- `02_late_payment_updates.sql`
- `03_reset_demo_state.sql`

Purpose of each script:

- `01_append_orders_batch.sql`
  - inserts brand-new orders, matching order items, and matching payments
  - supports the clean append-only incremental demo
- `02_late_payment_updates.sql`
  - inserts late-arriving payment/refund-related records tied to existing order IDs
  - supports the lesson that naive incremental logic may miss changed historical business state or cause excessive churn
- `03_reset_demo_state.sql`
  - removes trainer-added demo rows and restores the shared raw source tables to the expected baseline before the next session

Preferred design principle:

- for late updates, prefer inserting new source events tied to existing orders over mutating old raw records in place
- this is more realistic for event-style ingestion and makes the downstream incremental lesson cleaner

#### 4. Bias the base data and DML events toward the planned demos

The training data should not just be larger; it should make the workshop easier to teach.

For `fct_orders` incremental and churn:

- the base dataset should already contain realistic append-style order history
- `01_append_orders_batch.sql` should add clearly new orders and their downstream line/payment records
- `02_late_payment_updates.sql` should add a small but meaningful number of late-arriving events affecting existing order IDs

For `fct_order_items` pruning/clustering:

- the base dataset should preserve strong date, shop, and potion-level filtering opportunities
- repeated workload queries should make it possible to identify likely pruning/clustering candidates from usage patterns

For `int_orders_with_payments` join health:

- the base dataset should preserve enough split-payment and multi-line-order behavior that fanout mistakes become visible quickly

### Recommended data build outputs

The data-foundation phase should produce at least the following artifacts:

#### Active base seed set

- `seeds/large_data/abra_pos/raw_orders.csv`
- `seeds/large_data/abra_pos/raw_order_items.csv`
- `seeds/large_data/abra_pos/raw_payments.csv`

#### Trainer-run Snowflake scripts

- `training_assets/snowflake_scripts/01_append_orders_batch.sql`
- `training_assets/snowflake_scripts/02_late_payment_updates.sql`
- `training_assets/snowflake_scripts/03_reset_demo_state.sql`

#### Documentation

Need a short trainer-facing data-setup note that explains:

- what the large base dataset contains
- when to run each Snowflake script
- what each script changes in the raw source data
- how to reset the shared source tables back to baseline
- which demos depend on which scripts

Recommended location:

- `docs/demo_data.md`

### Recommended next implementation tasks for data foundation

1. confirm `seeds/large_data/` as the stable workshop seed baseline
2. create `training_assets/snowflake_scripts/01_append_orders_batch.sql`
3. create `training_assets/snowflake_scripts/02_late_payment_updates.sql`
4. create `training_assets/snowflake_scripts/03_reset_demo_state.sql`
5. document the trainer reset/apply flow in `docs/demo_data.md`

### Reminder: data foundation unlocks the rest of the build

Once the large base seed history and trainer-run Snowflake scripts are in place, we can build the highest-priority demo models with confidence:

- `fct_orders`
- `int_orders_with_payments`
- `dim_wizards`
- `fct_order_items`
- `fct_wizard_order_behavior`

That is the right next step.

