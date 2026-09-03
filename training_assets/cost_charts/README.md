# Cost optimization dashboard (dbt-charts)

A [dbt-charts](https://github.com/dbt-labs/dbt-charts) board visualizing the
output of the cost optimization package against this workshop's Snowflake
data: savings by domain, savings by effort category, the ranked
optimization backlog, per-model recommendations for the 5 lab-flow models,
warehouse optimizations, and cross-domain insights.

dbt-charts is not installed as part of the standard workshop setup and
won't be publicly available until it launches at the conference, so this
folder ships two things:

1. **A static preview** (`preview/cost_optimization_overview.html`) -
   a self-contained snapshot you can open right now, no install required.
2. **The board source** (`dbt_charts.yml`, `dbt_project.yml`,
   `charts/cost_optimization_overview.yml`) - the actual code, so anyone
   who installs dbt-charts after the conference can render it live against
   fresh data.

## View the static preview now

Open `preview/cost_optimization_overview.html` directly in a browser (just
double-click it, or `open preview/cost_optimization_overview.html` on
macOS). It's a single self-contained file, fonts and all - no server, no
network connection, no dbt-charts install needed. It even preserves one bit
of interactivity: the "Warehouse optimizations" table has 2 rows split
across 2 pages, and the page-2 button works in this static file too.

This preview is a snapshot from 2026-08-25 against live workshop data. It
will drift out of date as the underlying Snowflake data changes - to see
current numbers, render it live (below).

## Render it live (after the conference / once dbt-charts is installed)

### 1. Install dbt-charts

```bash
pip install "dbt-charts[snowflake]"
# or, to keep it isolated from your other Python environments:
pipx install "dbt-charts[snowflake]"
```

This installs the `dct` CLI. Confirm it worked:

```bash
dct --version
```

### 2. Confirm your Snowflake connection

This board reuses the **same `merlinco_apothecaries` profile** you already
have in `~/.dbt/profiles.yml` for running `dbt build` in this project - no
separate credentials to set up. If you can already run `dbt build` from the
repo root, you're set.

This board reads from `APOTHECARIES.DBT_JSTAYTON_DBT_COST_OPTIMIZATION`, a
schema owned by the trainer account, not your own dev schema. Your workshop
role needs `SELECT` on that schema for this to work.

This has been verified end-to-end with a trainer credential under the
`merlinco_apothecaries` profile name (same config this board ships with) -
`dct validate` and `dct render` both succeed with zero warnings. What's
**not** yet verified is whether the shared *attendee* workshop role (as
opposed to a trainer credential) has been granted `SELECT` on
`APOTHECARIES.DBT_JSTAYTON_DBT_COST_OPTIMIZATION`.

> **Trainer note:** confirm the attendee-facing workshop role has been
> granted `SELECT` on `APOTHECARIES.DBT_JSTAYTON_DBT_COST_OPTIMIZATION`
> before the event. If it hasn't, either grant it or point
> `dbt_charts.yml`'s `sources.cost_optimization.profile` at a profile that
> does have access.

### 3. Validate and render

From this folder (`training_assets/cost_charts/`):

```bash
# Fast schema check, no warehouse hit:
dct validate

# Render a fresh static snapshot:
dct render charts/cost_optimization_overview.yml --format html --output preview/cost_optimization_overview.html

# Or launch a live, auto-reloading dashboard server:
dct serve
```

`dct serve` prints the URL it's bound to (defaults to
`http://localhost:8501/cost_optimization_overview/`, per the `server.port`
setting in `dbt_charts.yml`). Edit `charts/cost_optimization_overview.yml`
and refresh the page to see changes without restarting anything.

## What's in this folder

```text
dbt_charts.yml                       # dbt-charts project config (connection, server port)
dbt_project.yml                      # minimal stub dct requires as a sibling to dbt_charts.yml
charts/
  cost_optimization_overview.yml     # the board: queries, charts, layout - the file to edit
preview/
  cost_optimization_overview.html    # static snapshot, viewable with no install (see above)
```

`dbt_project.yml` here is intentionally minimal and unrelated to the real
workshop `dbt_project.yml` at the repo root - it exists only because dct
requires *some* `dbt_project.yml` next to `dbt_charts.yml` to resolve
`profiles.yml`, even though this board queries fully-qualified tables
directly and never calls `ref()` or `source()`.

## Known limitations (as of dbt-charts 0.5.0)

- **PDF export is broken** in this version (`ERR-INTERNAL`: "The SVG's
  nesting depth is too high"). Use `--format html` or `--format png`
  instead.
- **The "Warehouse optimizations" table paginates** to 1 row per page even
  though there are only 2 rows total. Both rows are correct and complete -
  confirmed directly - but a viewer who doesn't click to page 2 will miss
  the second row. dct's own validator confirms table charts use "a fixed
  sizing contract" with no supported height override, so there's no known
  fix on the board-authoring side.
- Every SQL result column name is **lowercased** by dct regardless of how
  it's written in the query - if you add new queries/charts, alias columns
  in lowercase (`AS my_column`, not `AS MY_COLUMN`) or field references
  like `x:`/`y:`/`color:` will silently fail to match.
