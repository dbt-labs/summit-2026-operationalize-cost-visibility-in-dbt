# `answer_key/` — trainer reference and take-home optimized models

This folder contains the optimized target states for the cost-optimization workshop. The models are enabled and use distinct `__optimized` names so trainers can build stable benchmark DAGs without replacing the intentionally inefficient models in `models/intermediate/` and `models/marts/`.

Attendees do not inspect or build this directory during the live workshop. They implement the optimizations in their own branches and developer schemas. Because attendee branches cannot be committed, this directory becomes the take-home reference after the exercises.

## Layout

```text
answer_key/
├── intermediate/            # optimized grain-aligned and modular rollups
├── marts/                   # optimized dimensions and facts
├── _optimized_marts.yml     # tags, descriptions, contracts, and tests
└── *.md                     # symptom/fix/comparison notes for major demos
```

## How it is wired

- Optimized benchmark models are tagged `optimized`.
- The optimized marts have enforced contracts and model-specific tests.
- Optimized intermediates have grain descriptions and targeted tests.
- Starter benchmark marts are tagged `unoptimized` in `models/marts/_marts.yml`.
- Shared staging, dimensions, and supporting intermediates are included through normal `ref()` lineage.
- Optimized models do not define duplicate Semantic Layer objects; active semantic definitions remain attached to the starter marts.

## Attendee exclusion

The workshop's attendee full-build command excludes this directory through its tag:

```text
dbt build --exclude tag:optimized
```

Trainers should verify after any future tag changes that this returns no nodes:

```text
dbt ls --select path:models/answer_key --exclude tag:optimized
```

## Trainer benchmark selectors

Build optimized target models only:

```text
dbt build --select tag:optimized
```

Build the complete optimized DAG, including ancestors:

```text
dbt build --select +tag:optimized
```

The direct optimized selector currently includes:

- `dim_wizards__optimized`;
- `fct_orders__optimized`;
- `fct_order_items__optimized`;
- `fct_wizard_order_behavior__optimized`;
- `int_orders_with_payments__optimized`;
- `int_wizard_order_behavior_base`; and
- `int_wizard_potion_preferences`.

Run starter and optimized benchmark DAGs sequentially when they share the same target schema because their upstream relations overlap.

## Model mapping

| Workshop topic | Optimized asset |
|---|---|
| Workload-driven clustering | `marts/fct_order_items__optimized.sql` |
| Persisted wizard dimension | `marts/dim_wizards__optimized.sql` |
| Changed-key merge incremental | `marts/fct_orders__optimized.sql` |
| Grain-aligned order joins | `intermediate/int_orders_with_payments__optimized.sql` |
| Customer behavior base rollup | `intermediate/int_wizard_order_behavior_base.sql` |
| Customer potion-preference rollup | `intermediate/int_wizard_potion_preferences.sql` |
| Modular customer behavior mart | `marts/fct_wizard_order_behavior__optimized.sql` |

The companion notes explain each symptom, diagnosis, implementation, expected benefit, and evidence plan. Facilitators may use them during preparation and debrief, then point attendees to them as the take-home reference after the workshop.
