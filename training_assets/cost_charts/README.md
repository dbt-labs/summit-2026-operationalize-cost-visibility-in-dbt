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

## Run it yourself

1. **Install dbt-charts** (once it's publicly released):

   ```bash
   pip install "dbt-charts[snowflake]"
   ```

2. **Build the cost optimization package's models**:

   ```yaml
   # vars.yml
   dbt_cost_optimization_enabled: true
   ```

   ```bash
   dbt deps
   dbt build --select tag:dbt_cost_optimization
   ```

3. **Replace the database and schema.** In
   `charts/cost_optimization_overview.yml`, find-and-replace every
   occurrence of `APOTHECARIES.DBT_JSTAYTON_DBT_COST_OPTIMIZATION` with
   your own `<database>.<schema>` (the package builds into
   `{{ target.schema }}_dbt_cost_optimization`).

4. **Launch the dashboard**:

   ```bash
   dct validate
   dct serve
   ```

   `dct serve` prints the URL it's bound to (defaults to
   `http://localhost:8501/cost_optimization_overview/`). Or render a fresh
   static snapshot instead of serving live:

   ```bash
   dct render charts/cost_optimization_overview.yml --format html --output preview/cost_optimization_overview.html
   ```

This board uses hardcoded table paths instead of `{{ ref(...) }}` because
`ref()` doesn't yet resolve inside dbt-charts board queries - that's
expected to be added in a future dbt-charts release, at which point step 3
goes away.

## Known limitations (as of dbt-charts 0.5.0)

- PDF export is broken (`ERR-INTERNAL`: "The SVG's nesting depth is too
  high"). Use `--format html` or `--format png` instead.
- Every SQL result column name is lowercased by dct regardless of how it's
  written in the query - alias new columns in lowercase (`AS my_column`),
  or `x:`/`y:`/`color:` field references will silently fail to match.
