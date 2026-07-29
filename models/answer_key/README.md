# answer_key/ — optimized reference solutions (disabled)

This folder now contains the optimized after-states for the workshop models used in the cost optimization training.
They're here so trainers and attendees can compare the intentionally bad workshop models in `models/` against cleaner, more efficient implementations.

## Layout

Mirrors the main `models/` tree — `staging/`, `intermediate/`, `marts/`, plus companion markdown notes for major workshop demos.

```text
answer_key/
├── staging/
├── intermediate/
├── marts/
└── *.md         # companion notes for major workshop demos
```

## How it's wired

- The whole folder is **disabled** in `dbt_project.yml` (`answer_key: +enabled: false`),
  so these models are parsed (valid, lintable SQL) but never built, and they stay out
  of the normal DAG, `dbt build`, docs, and the semantic layer.
- For existing models that were intentionally worsened in the main DAG, the answer key
  often preserves the original or improved implementation.
- For net-new workshop demos, the answer key holds the intended optimized end state.

## Using it

- **Read to compare:** just open the files.
- **Use in training:** compare the bad-state model in `models/` to the optimized counterpart in `models/answer_key/`.
- **Reference the companion docs:** major workshop demos have markdown notes that explain symptom, fix, expected benefit, and comparison workflow.

## Current workshop-focused contents

Representative answer-key assets include:

- `intermediate/int_orders_with_payments.sql`
- `marts/fct_orders.sql`
- `marts/dim_wizards.sql`
- `marts/fct_order_items.sql`
- `intermediate/int_wizard_order_behavior_base.sql`
- `intermediate/int_wizard_potion_preferences.sql`
- `marts/fct_wizard_order_behavior.sql`
