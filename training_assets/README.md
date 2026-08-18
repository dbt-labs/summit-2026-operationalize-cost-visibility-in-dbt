# Trainer handoff

This directory contains the facilitator-facing assets for the Merlin & Co. cost-optimization workshop.

## Workshop operating model

Attendees work directly in the starter models and build the optimized assets together. The enabled models in `models/answer_key/` are trainer references and take-home resources; they are not inspected or built during the live labs.

Attendee full-build command:

```text
dbt build --exclude tag:optimized
```

Run it exactly twice:

1. at the beginning of Demo 00 to establish each developer schema; and
2. at the end of Demo 06 to compare the completed project with the opening baseline.

Use targeted model builds and focal-model full refreshes between those two runs.

## Demo sequence

1. `00_project_tour_and_cost_contract.md`
2. `01_cluster_order_items_from_workload.md`
3. `02_persist_reused_wizard_dimension.md`
4. `03_process_changed_orders_incrementally.md`
5. `04_fix_exploding_order_join.md`
6. `05_refactor_customer_behavior_mart.md`
7. `06_optimize_jobs_and_test_scope.md`

`07_conclusion_notes.md` is slide-ready wrap-up material rather than an eighth demo.

The sequence deliberately increases attendee independence: follow-along physical tuning, small materialization/config changes, independent grain repair, then an open-ended architecture refactor.

The published durations are current planning budgets only. Capture actual segment times during the dry run and cut or compress material wherever the rehearsal exceeds the workshop schedule.

## Current optimization map

| Demo subject | Starter state | Trainer/take-home target |
|---|---|---|
| Physical design | `fct_order_items` is an unclustered table | Cluster by `ordered_date` and `shop_id` based on workload |
| Materialization | `dim_wizards` is a repeatedly recomputed view | Persist as a table |
| Incremental processing | `fct_orders` rewrites full history | Merge changed `order_id`s using a stable watermark |
| Join health | `int_orders_with_payments` fans out native grains | Aggregate items and payments to order grain first |
| Modular architecture | `fct_wizard_order_behavior` is a mixed-grain all-in-one mart | Focused customer-grain rollups feed a thin mart |

## Live versus prepared evidence

Live:

- opening and closing attendee full builds;
- targeted focal-model builds;
- one before/after `fct_order_items` consumption query;
- one before/after `dim_wizards` consumption query; and
- one dbt State/model-reuse job.

Prepared:

- remaining consumption-query history;
- incremental before/after build screenshots and profiles;
- CI, benchmark, test-scope, and cleanup job runs; and
- fallback screenshots for every warehouse-dependent comparison.

No source ingestion runs live. `snowflake_scripts/04_weekly_orders_change_batch.sql` is for trainer-managed history and evidence generation.

## Supporting assets

- `demo_outlines/00_...` through `06_...`: facilitator-ready plans for the seven workshop modules.
- `demo_outlines/07_conclusion_notes.md`: slide-ready benchmark interpretation, ROI framing, and closing narration.
- `snowflake_scripts/`: workshop account setup and trainer-managed source history.
- `TODO.md`: current delivery decisions, evidence checklist, and remaining work.
- `docs/training_materials/PRESENTATION_OUTLINE.md`: concise deck narrative.
- `docs/training_materials/full_demo_operations_guide.md`: data and build operations.
- `docs/training_materials/jobs.md`: job configuration and live-demo plan.

## Current benchmark context

The observed full-build comparison is 3:13 versus 2:46, a 27-second or 14.0% reduction. Use `demo_outlines/07_conclusion_notes.md` for the complete interpretation and slide language.

