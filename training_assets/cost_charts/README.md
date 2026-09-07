# Cost optimization dashboard (dbt-charts)

A [dbt-charts](https://github.com/dbt-labs/dbt-charts) board visualizing the
cost optimization package's output: savings by domain and effort category,
the ranked optimization backlog, per-model recommendations, warehouse
optimizations, and cross-domain insights.

## View without installing anything

Open `preview/cost_optimization_overview.html` in a browser (double-click
it, or `open preview/cost_optimization_overview.html` on macOS). It's a
self-contained snapshot - no install, no server, no network connection
needed.

> **Trainer note:** as shipped, this board points at the trainer's own
> build (`APOTHECARIES.DBT_JSTAYTON_DBT_COST_OPTIMIZATION`). If attendees
> should be able to run the board as-is (without building their own copy
> first), grant the shared workshop role `SELECT` on that schema before the
> event.

## Run it yourself

1. **Install dbt-charts** (once it's publicly released):

   ```bash
   pip install "dbt-charts[snowflake]"
   ```

2. **Build the cost optimization package's models**, from the repo root:

   ```bash
   dbt deps
   dbt build --select tag:dbt_cost_optimization --vars '{dbt_cost_optimization_enabled: true}'
   ```

   Your `~/.dbt/profiles.yml` profile needs a `dev` target (or add
   `--target <name>` matching whatever your profile actually calls it).

3. **Replace the database and schema.** In
   `training_assets/cost_charts/charts/cost_optimization_overview.yml`,
   find-and-replace every occurrence of
   `APOTHECARIES.DBT_JSTAYTON_DBT_COST_OPTIMIZATION` with your own
   `<database>.<schema>` (the package builds into
   `{{ target.schema }}_dbt_cost_optimization`, and your role needs
   `SELECT` there, which it normally already has on its own schema).

4. **Launch the dashboard**, from `training_assets/cost_charts/`:

   ```bash
   dct validate
   dct serve
   ```

   `dct serve` prints the URL it's bound to (defaults to
   `http://localhost:8501/cost_optimization_overview/`). To render a static
   snapshot instead of serving live, output somewhere other than
   `preview/cost_optimization_overview.html` so you don't overwrite the
   shipped trainer snapshot:

   ```bash
   dct render charts/cost_optimization_overview.yml --format html --output /tmp/my_preview.html
   ```

This board uses hardcoded table paths instead of `{{ ref(...) }}`:
`{{ ref(...) }}` currently fails inside dbt-charts 0.5.0 board-defined
queries (confirmed across every adapter type, not specific to Snowflake),
so step 3 is a manual workaround until that's fixed upstream.

## Known limitations (as of dbt-charts 0.5.0)

- PDF export is broken (`ERR-INTERNAL`: "The SVG's nesting depth is too
  high"). Use `--format html` or `--format png` instead.
- Every SQL result column name is lowercased by dct regardless of how it's
  written in the query - alias new columns in lowercase (`AS my_column`),
  or `x:`/`y:`/`color:` field references will silently fail to match.
