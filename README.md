# Merlin & Co. Apothecaries

Merlin & Co. Apothecaries is a Snowflake + dbt training project built for a dbt Summit workshop on **cost optimization through dbt**.

The workshop uses intentional anti-patterns in a realistic retail analytics project to show how dbt can help teams:

1. make queries run faster;
2. make queries read less data; and
3. prevent inefficient model and job patterns from recurring.

Every module follows symptom → diagnosis → fix → prevention.

## What this repo is for

This is a hands-on training repo. The primary `models/` layers contain the intentionally messy or suboptimal workshop models. Attendees improve those models in their own branches and developer schemas.

Enabled optimized counterparts live in `models/answer_key/` with `__optimized` names, model properties, tests, and companion notes. They are trainer benchmark assets and take-home references. Attendees do not inspect or build them during the live labs.

The attendee full-build command is:

```text
dbt build --exclude tag:optimized
```

Trainer benchmark DAGs remain selectable with:

```text
dbt build --select +tag:unoptimized
dbt build --select +tag:optimized
```

Run trainer benchmark builds sequentially when they share a target schema because their upstream relations overlap.

## Workshop flow

Attendees run exactly two full builds:

1. an opening build during project orientation to establish their developer schemas; and
2. a closing build after all targeted model changes to compare whole-project runtime.

Between them, exercises use targeted builds or focal-model full refreshes. The live workshop runs one before/after consumption query for `fct_order_items`, one for `dim_wizards`, and one dbt State/model-reuse job. Remaining workload history, incremental timing, and job comparisons are prepared in advance.

## Workshop themes

### Model-level optimizations

- workload-driven clustering and pruning;
- view-to-table conversion for frequently queried dimensions;
- table-to-merge-incremental conversion based on observed ingestion behavior;
- unhealthy joins and grain alignment; and
- refactoring oversized mixed-grain SQL into focused dbt models.

### Job-level optimizations

- broad job selectors versus purpose-built selectors;
- dbt State, deferral, and model reuse;
- slim CI;
- test-scope optimization; and
- CI cleanup for incremental validation.

### Storage and environment topics

- write amplification and churn;
- clustering and reclustering tradeoffs;
- transient versus permanent tables;
- clone awareness; and
- development and CI cleanup patterns.

## Repo layout

```text
models/
├── staging/                 # stg_<system>__<entity> source cleanup and typing
├── intermediate/            # shared starter/supporting intermediate models
├── marts/                   # workshop starter marts, including intentional bad states
└── answer_key/              # trainer/take-home __optimized models and notes
macros/                      # shared cleanup and utility macros
seeds/large_data/            # portable raw-data seed baseline
training_assets/
├── demo_outlines/           # facilitator-ready plans for Demos 00–06
├── snowflake_scripts/       # setup and trainer-managed history generation
├── cost_charts/             # dbt-charts dashboard of cost-optimization results (see its README)
├── README.md                # trainer handoff
└── TODO.md                  # current delivery plan and remaining work
analyses/
├── dim_wizards/             # repeated dimension-consumption workload
└── fct_order_items/         # repeated pruning/clustering workload
docs/
├── merlinco/                # style guide, data dictionary, and ERD
└── training_materials/      # presentation, operations, and jobs guides
```

## Data setup

The repository seed baseline lives in `seeds/large_data/` for portable setup and reset. Its key commerce files are approximately:

- `raw_orders`: 75k rows;
- `raw_order_items`: 253k rows; and
- `raw_payments`: 86k rows.

The live workshop uses a trainer-managed, larger Snowflake baseline so performance differences are visible. Attendees build into their own schemas against shared raw relations and do not reseed or run source ingestion during the workshop.

`training_assets/snowflake_scripts/04_weekly_orders_change_batch.sql` creates realistic new and historically changed orders for trainer-managed query-history generation. It is not part of the live attendee flow.

## Key workshop models

| Sequence | Optimization | Starter model | Trainer/take-home target |
|---:|---|---|---|
| 01 | Workload-driven clustering | `models/marts/fct_order_items.sql` | `models/answer_key/marts/fct_order_items__optimized.sql` |
| 02 | Frequently queried view to table | `models/marts/dim_wizards.sql` | `models/answer_key/marts/dim_wizards__optimized.sql` |
| 03 | Full rebuild to changed-key merge incremental | `models/marts/fct_orders.sql` | `models/answer_key/marts/fct_orders__optimized.sql` |
| 04 | Exploding join / grain alignment | `models/intermediate/int_orders_with_payments.sql` | `models/answer_key/intermediate/int_orders_with_payments__optimized.sql` |
| 05 | Oversized mart to modular customer-grain rollups | `models/marts/fct_wizard_order_behavior.sql` | `models/answer_key/marts/fct_wizard_order_behavior__optimized.sql` |

The modular refactor also uses:

- `models/answer_key/intermediate/int_wizard_order_behavior_base.sql`; and
- `models/answer_key/intermediate/int_wizard_potion_preferences.sql`.

## Quickstart

For an attendee or starter-only development build:

```text
dbt deps
dbt parse
dbt seed
dbt build --exclude tag:optimized
```

Notes:

- `dbt seed` supports the portable repository baseline; live workshop attendees use trainer-managed shared raw data.
- Staging models read workshop tables through `source()` declarations.
- `--exclude tag:optimized` keeps trainer/take-home answer-key models out of attendee builds.
- Trainers can use the tag selectors above for controlled benchmark generation.

Local development uses `~/.dbt/profiles.yml` (see `profiles.example.yml`). In dbt Platform environments, the connection is managed there.

## Trainer notes

Start with:

- `training_assets/README.md`;
- `training_assets/demo_outlines/`;
- `docs/training_materials/PRESENTATION_OUTLINE.md`;
- `docs/training_materials/full_demo_operations_guide.md`;
- `docs/training_materials/jobs.md`; and
- `docs/training_materials/TRAINING_NOTES.md` for the longer planning history.

## Source systems

| System | Example tables |
|---|---|
| Abracadabra POS | `raw_orders`, `raw_order_items`, `raw_payments`, `raw_potions` |
| Grimoire CRM | `raw_customers`, `raw_guilds`, `raw_guild_memberships` |
| Alembic Ops | `raw_shops`, `raw_suppliers`, `raw_ingredients`, `raw_potion_ingredients`, `raw_brew_events` |

See `docs/merlinco/DATA_DICTIONARY.md` and `docs/merlinco/ERD.md` for full details.
