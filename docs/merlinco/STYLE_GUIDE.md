# Modeling style guide

The human-readable companion to [CLAUDE.md](../CLAUDE.md). Same rules, with the
*why* — so both people and AI assistants produce the same code, and reviewers have
a shared standard to point at. Consistency is what lets this project scale: a
reviewer (or a contract test) can trust a new model because it looks like every
other model.

## Project shape

```
seeds/medium_data/   raw CSVs; `dbt seed` loads them into APOTHECARIES.RAW
models/
  staging/<source>/  _<source>__sources.yml   — raw tables declared as SOURCES (+ raw tests)
                     stg_<source>__<entity>   — clean + type, reads one source(), 1:1
  intermediate/      int_<description>        — joins, fan-out, aggregation
  marts/             dim_/fct_                — contracted, tested, exposed
macros/              shared cleaning logic (the reuse layer)
```

**Seeds vs. sources.** Seeds keep the project self-contained (any Snowflake account, no
external EL). But staging reads through `source()`, not `ref()` on the seed, because
`source()` is the real-world pattern and gives us a source contract, source-level tests,
and freshness. dbt does not create a lineage edge from a seed to the source pointing at
it, so **run `dbt seed` before `dbt build`** (the data is static, so this is rare).

## Layering, in detail

**Staging** is a thin, predictable clean-up layer. One model per raw table, selecting
from exactly one `source()`. Rename to conventions, cast to real types, apply the shared
cleaning macros. No joins, no business logic — this keeps staging cheap to reason about
and lets everything downstream assume clean inputs.

**Intermediate** is where joins and grain changes happen (rolling payments up to order
grain, collapsing SCD2 to current rows). Ephemeral, so it never clutters the warehouse;
it exists to keep marts readable.

**Marts** are the product. Dimensions (`dim_`) describe entities; facts (`fct_`) record
events at a stated grain. This is the only layer with enforced contracts, the only layer
other tools/BI/AI should read, and the only layer exposed via the semantic layer.

## Naming and structure

- Import CTEs first (one per `ref`), transformation CTEs in the middle, a `final` CTE,
  then `select * from final`.
- `snake_case` everywhere; lowercase SQL keywords and identifiers.
- PK = `<entity>_id`; booleans `is_*`/`has_*`; timestamps `*_at` (TIMESTAMP_NTZ), dates `*_date`.
- Money: keep `*_copper` (raw integer) and expose `*_gold` (NUMBER(38,2)). Never report in copper.

## The deliberate data quirks (and how we handle them)

The raw feed is intentionally messy so staging has real work (see
[DATA_DICTIONARY.md](DATA_DICTIONARY.md#deliberate-data-quirks)). The handling is
centralized where reuse pays off:

| Quirk | Handled by |
|---|---|
| Timestamp columns (`*_at`) | explicit `timestamp_ntz` casts in staging |
| Messy booleans (`Y/N/yes/no/TRUE/FALSE`) | `to_boolean()` |
| Copper integer prices | `copper_to_gold()` |
| Inconsistent CRM region coding | `conform_region()` |
| Mixed-case categoricals | `lower(trim(...))` in staging |

## Testing standard

- Every PK: `unique` + `not_null`.
- Every FK: `relationships`.
- Every normalized categorical: `accepted_values` (this catches a new raw variant the
  moment it appears, instead of it silently flowing downstream).
- Money and other must-be-present columns: `not_null`.

## Contracts

Marts declare a `data_type` for every column and set `contract: {enforced: true}`. We
cast each column explicitly in the SQL to the declared type. A contract turns a silent
schema drift (a renamed column, a changed type from an AI edit) into a **loud build
failure** — which is exactly what makes AI-authored changes safe to accept.

## Semantic layer

Metrics are defined once (`_semantic_models.yml` + `metrics.yml`) and queried through
the semantic layer. This is the governance boundary for self-serve and AI-assisted
analytics: everyone gets the same definition of "revenue," and no one re-derives it in
ad hoc SQL.

## CI

Every PR runs `dbt parse` + `sqlfluff lint` (no warehouse needed) via GitHub Actions,
plus the CODEOWNERS check. The full `dbt build` gate (which needs Snowflake) runs as a
dbt platform CI job once the repo is linked.
