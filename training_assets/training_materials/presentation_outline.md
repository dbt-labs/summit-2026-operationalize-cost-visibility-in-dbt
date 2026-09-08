# Presentation outline: cost optimization through dbt

This is the concise presenter-facing map from the current repository to the workshop deck.

## Core workshop message

Using dbt correctly helps teams:

1. make queries run faster;
2. make queries read less data; and
3. prevent inefficient model and job patterns from recurring.

Every module follows symptom → diagnosis → fix → prevention. The labs become progressively more independent: attendees first follow along, then make a small configuration decision, then solve grain and architecture problems on their own.

## Workshop operating contract

Attendees build only the workshop DAG in their developer schemas. The enabled models under `models/answer_key/` are trainer references and take-home resources; attendees do not inspect or build them during the live exercises.

Use this command for both attendee full builds:

```text
dbt build --exclude tag:optimized
```

The first full build starts during Demo 00, immediately after environment orientation. It establishes every attendee's development relations before the model exercises begin. The second full build runs at the end, after the targeted model builds and full refreshes, to compare whole-project runtime.

During the exercises:

- build or full-refresh only the focal model needed to validate the change;
- do not run the optimized tag in attendee schemas;
- do not run live source ingestion;
- run one representative consumption query before and after for `fct_order_items` and one for `dim_wizards`; and
- use prepared query history, profiles, screenshots, and job runs for the remaining evidence.

Trainer benchmark commands remain available outside the attendee flow:

```text
dbt build --select +tag:unoptimized
dbt build --select +tag:optimized
```

Run those sequentially when they share a target schema because their upstream relations overlap.

## Current projected presentation order

These durations are current-state planning budgets, not observed delivery times or commitments. The dry run should measure each segment under realistic workshop conditions. If the workshop runs long, cut or compress material based on the rehearsal results rather than forcing every planned beat into the live session.

| File | Focus | Interaction | Planning budget |
|---|---|---|---:|
| `00_project_tour_and_cost_contract.md` | Project orientation, evidence standard, and initial developer build | Facilitator walkthrough | 12 min |
| `01_cluster_order_items_from_workload.md` | Derive clustering keys from observed workload | Follow-along demo | 20 min |
| `02_persist_reused_wizard_dimension.md` | Choose persistence from repeated consumption | Short guided change | 15 min |
| `03_process_changed_orders_incrementally.md` | Match an incremental strategy to historical ingestion | Guided diagnosis plus 5–10 min individual implementation | 25 min |
| `04_fix_exploding_order_join.md` | Align native grains before joining | Independent fix with group debrief | 20 min |
| `05_refactor_customer_behavior_mart.md` | Refactor a mixed-grain mart from a Jira-style ticket | Main independent lab | 35 min |
| `06_optimize_jobs_and_test_scope.md` | State, CI/test scope, and environment hygiene | Follow-along jobs demo and wrap-up | 20 min |

Current projected content time: approximately 2 hours 27 minutes before a break or open discussion. Rebaseline this total after each full dry run and record any cuts in the facilitator outlines.

## Module map

### 00. Project tour and cost contract

- Introduce the project, shared raw data, developer-schema workflow, and cost evidence standard.
- Start `dbt build --exclude tag:optimized` immediately so setup compute runs during the orientation.
- Explain that `models/answer_key/` is a take-home implementation reference, not a live workshop surface.
- Establish that whole-project elapsed time is only one measure of value.

### 01. Workload-driven clustering

- **Symptom:** repeated filtered queries scan more of a large line-grain fact than necessary.
- **Model:** `models/marts/fct_order_items.sql`.
- **Observed keys:** `ordered_date`, `shop_id`.
- **Workload history:** five analyses under `analyses/fct_order_items/`; run only one representative query live before and after.
- **Flow:** inspect query history and profile, demonstrate candidate-key discovery, add `cluster_by`, full-refresh the focal model, and compare pruning.
- **Tradeoff:** clustering can reduce read cost while adding write and reclustering cost.

### 02. Persist a reused wizard dimension

- **Symptom:** repeated consumers recompute the same dimension enrichment through a view.
- **Model:** `models/marts/dim_wizards.sql`.
- **Workload history:** five analyses under `analyses/dim_wizards/`; run only one representative query live before and after.
- **Flow:** inspect repeated consumption, change `view` to `table`, build the focal model, and compare the consumer query profile.
- **Takeaway:** materialization follows reuse and freshness requirements.

### 03. Process changed orders incrementally

- **Symptom:** historical query and build evidence shows a growing fact repeatedly scanning and rewriting mostly unchanged history.
- **Model:** `models/marts/fct_orders.sql`.
- **Flow:** inspect ingestion cadence, changed-row ratio, bytes written, target grain, and update behavior; attendees implement the table-to-merge-incremental configuration in 5–10 minutes.
- **Debrief:** compare Snowflake incremental strategies and explain why `merge` plus `order_id` fits late updates and new orders.
- **Evidence:** use prepared before/after build screenshots and query profiles. Do not run the weekly source batch live and do not reset a baseline during the workshop.

### 04. Fix the exploding order join

- **Symptom:** line items and payment attempts multiply before the model returns to order grain.
- **Model:** `models/intermediate/int_orders_with_payments.sql`.
- **Flow:** trainers frame the profile and native grains; attendees independently aggregate lower-grain inputs to `order_id` before joining.
- **Validation:** build the downstream focal order fact so the intermediate SQL executes.
- **Transition:** carry the grain-alignment lesson directly into the larger customer-mart refactor without reteaching it.

### 05. Refactor the customer behavior mart

- **Symptom:** one 185-line mart mixes customer, order, payment, line, preference, and cost responsibilities and carries lower-grain data too far.
- **Model:** `models/marts/fct_wizard_order_behavior.sql`.
- **Format:** issue a Jira-style refactor ticket with symptoms, constraints, required output, and cost evidence; attendees design and implement the solution independently.
- **Debrief:** compare approaches with the trainer reference, targeted build times, query shape, and projected annual savings.
- **Testing/governance framing:** tests and contracts help preserve assumptions, but gaps in grain-aware validation can allow fanout, extra compute, and write amplification to persist. Shape protection is supporting context, not the workshop's main lesson.

### 06. Optimize jobs and test scope

- Trigger only the prepared dbt State/model-reuse job live.
- Spend most of the module explaining what dbt State compares, what work can be reused, and how state differs from deferral.
- Show pre-run evidence for CI before/after, benchmark jobs, test-scope changes, and cleanup behavior.
- Walk through the commands and job configuration without waiting for those jobs to execute.
- End with the second `dbt build --exclude tag:optimized` and compare it with the opening build.

## Conclusion and benchmark interpretation

Use `training_assets/demo_outlines/07_conclusion_notes.md` as the slide and speaker-note source of truth for the wrap-up. It contains:

- the observed 3:13 → 2:46 comparison and 14.0% calculation;
- the illustrative 30-minute scale example;
- the explanation for why whole-project runtime understates some optimizations;
- the primary cost surface for each workshop change;
- annualization formulas and maintenance-cost caveats; and
- the recommended closing narration.

During the dry run, determine how much of that material fits the closing segment. Preserve the observed benchmark and multi-surface ROI takeaway first; move detailed interpretation to take-home material if time is tight.


## Evidence standard

For each model demo, show the relevant subset of:

- elapsed time;
- bytes scanned;
- rows entering and leaving join operators;
- partitions scanned and pruning behavior;
- spill;
- rows written or merged;
- repeated-query frequency; and
- warehouse credits where available.

Keep the workload, warehouse size, source snapshot, and relation state stable for every before/after comparison. Annualized savings should use observed execution frequency and credits or warehouse time, with assumptions stated explicitly.
