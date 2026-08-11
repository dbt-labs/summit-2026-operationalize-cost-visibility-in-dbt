# Merlin & Co. Apothecaries

Merlin & Co. Apothecaries is a Snowflake + dbt training project built for a dbt Summit workshop on **cost optimization through dbt**.

The workshop uses intentional anti-patterns in a realistic retail analytics project to show how dbt can help teams do two things:

1. make queries run faster
2. make queries read less data

The repo is designed so attendees can work through the full FinOps cycle:

1. identify the symptom
2. diagnose the root cause
3. apply the dbt fix
4. put a prevention mechanism in place

## What this repo is for

This is a hands-on training repo, not just a clean reference implementation.

That means the primary `models/` directory now contains intentionally messy or suboptimal examples used in the workshop. The optimized end states live in `models/answer_key/`, alongside companion documentation that explains:

- the symptom
- the root cause
- how the issue was identified
- what fix was applied
- why that fix was the right one
- how to compare before and after

## Workshop themes

The training is organized around model-level and job-level optimization patterns that transfer cleanly across platforms, even though Snowflake is the warehouse used in the demos.

### Model-level optimizations covered

- unhealthy joins / exploding joins
- table to incremental conversion
- refining incremental logic for late-arriving changes
- view to table conversion for frequently queried dimensions
- refactoring oversized all-in-one SQL into modular dbt models
- pruning / clustering based on observed workload patterns

### Job-level optimizations planned

- broad job selectors vs purpose-built selectors
- state and deferral
- slim CI
- test scope optimization
- CI cleanup support for incremental validation

### Storage / environment topics discussed

- transient vs permanent tables
- clone awareness
- write amplification and churn
- dev / CI cleanup patterns

## Repo layout

```text
models/
├── staging/                 # stg_<system>__<entity> — source cleanup and typing
├── intermediate/            # int_ models — joins, fanout, aggregation
├── marts/                   # dim_ / fct_ workshop models (some intentionally bad)
└── answer_key/              # optimized after-states + companion docs (disabled by default)
macros/                      # shared cleaning and utility macros
seeds/large_data/            # base training seeds loaded to APOTHECARIES.RAW
training_assets/
└── snowflake_scripts/       # trainer-run source-data scripts for incremental demos
analyses/                    # dashboard-style workload queries for the clustering demo
docs/
├── merlinco/
    ├── STYLE_GUIDE.md           # modeling + naming conventions
    ├── DATA_DICTIONARY.md       # source-table notes and deliberate raw-data quirks
    ├── ERD.md                   # schema diagram
└── LAB_procurement_slice.md     # legacy procurement lab brief retained in the repo
├── training_materials/
    ├── TRAINING_NOTES.md                         # full workshop planning and implementation notes
    ├── full_demo_operations_guide.md             # trainer-facing data operations guide
    ├── jobs.md                                   # trainer-facing jobs config outline and demo walkthrough
    ├── PRESENTATION_OUTLINE.md                   # trainer-facing rough presentation outline

```

## Data setup

The stable workshop seed baseline lives in `seeds/large_data/`.

Key commerce seed sizes are roughly:

- `raw_orders`: 75k rows
- `raw_order_items`: 253k rows
- `raw_payments`: 86k rows

These are large enough to make the optimization demos believable without making the environment cumbersome to reset.

For the incremental demo, trainers do **not** need attendees to reseed data. Trainers run the small weekly source delivery directly in Snowflake before the daily `fct_orders` build:

- `training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql`

The batch applies 18 raw-source changes affecting 8 parent order IDs, using one shared ingestion watermark. See `docs/training_materials/full_demo_operations_guide.md` for the trainer workflow.


## Key workshop demo models

### Existing models intentionally worsened in `models/`

- `models/intermediate/int_orders_with_payments.sql`
  - exploding join / grain mismatch
- `models/marts/fct_orders.sql`
  - full-table rebuild instead of incremental
- `models/marts/dim_wizards.sql`
  - view instead of table for a frequently queried dimension

### Net-new workshop model

- `models/marts/fct_wizard_order_behavior.sql`
  - intentionally oversized all-in-one mart for the modular refactor lab

### Workload-driven clustering demo

- `models/marts/fct_order_items.sql`
  - paired with dashboard-style analysis queries in `analyses/`

### Optimized answer-key versions

The optimized after-states live in `models/answer_key/`.

Representative examples include:

- `models/answer_key/intermediate/int_orders_with_payments.sql`
- `models/answer_key/marts/fct_orders.sql`
- `models/answer_key/marts/dim_wizards.sql`
- `models/answer_key/marts/fct_order_items.sql`
- `models/answer_key/marts/fct_wizard_order_behavior.sql`

Each major demo also has a companion markdown note in `models/answer_key/`.

## Quickstart

```bash
dbt deps
dbt parse
dbt seed
dbt build
```

Notes:

- `dbt seed` loads the raw CSVs into `APOTHECARIES.RAW`
- staging models read those tables via `source()` declarations
- the answer-key folder is disabled in normal project runs

Local development uses `~/.dbt/profiles.yml` (see `profiles.example.yml`). In dbt platform environments, the connection is managed there instead.

## Trainer notes

If you are presenting or inheriting the workshop, start here:

- `docs/TRAINING_NOTES.md`
- `docs/demo_data.md`

Those docs explain:

- what each module is demonstrating
- which model corresponds to which optimization
- how trainer-run data changes support the incremental demos
- how the before/after assets are organized

## Source systems

The raw data comes from three fictional source systems:

| System | Example tables |
|---|---|
| Abracadabra POS | `raw_orders`, `raw_order_items`, `raw_payments`, `raw_potions` |
| Grimoire CRM | `raw_customers`, `raw_guilds`, `raw_guild_memberships` |
| Alembic Ops | `raw_shops`, `raw_suppliers`, `raw_ingredients`, `raw_potion_ingredients`, `raw_brew_events` |

See `docs/DATA_DICTIONARY.md` and `docs/ERD.md` for full details.

