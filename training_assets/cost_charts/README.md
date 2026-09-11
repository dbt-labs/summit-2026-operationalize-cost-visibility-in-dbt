# Cost optimization dashboard (dbt-charts)

A [dbt-charts](https://github.com/dbt-labs/dbt-charts) board visualizing the
cost optimization package's output: a headline KPI row (estimated annual
savings, recommendation count, quick wins, top single recommendation),
savings by domain and effort category, the ranked optimization backlog,
per-model recommendations, warehouse optimizations, and cross-domain
insights.

The live board files (`dbt_charts.yml`, `charts/`) live at the **repo root**,
not in this folder. `dct` resolves every `{{ ref(...) }}` call in the queries
against `target/manifest.json`, and it looks for that manifest relative to
wherever `dbt_charts.yml` sits - so the board has to sit next to the real
`dbt_project.yml` for `ref()` to work. This folder just holds this README and
a static preview snapshot.

## View without installing anything

Open `preview/cost_optimization_overview.html` in a browser (double-click
it, or `open preview/cost_optimization_overview.html` on macOS). It's a
self-contained snapshot - no install, no server, no network connection
needed.

This snapshot reflects the current `ref()`-based, generic version of the
board. Regenerate it any time with `dct render` (step 4 below) so it stays
in sync with the board's queries.

## Run it yourself

1. **Install dbt-charts** (0.7.0 or later - `ref()` in board queries doesn't
   resolve correctly before 0.7.0):

   ```bash
   pip install "dbt-charts[snowflake]"
   # or, if already installed via pipx:
   pipx upgrade dbt-charts
   ```

2. **Build the cost optimization package's models**, from the repo root:

   ```bash
   dbt deps
   dbt build --select tag:dbt_cost_optimization --vars '{dbt_cost_optimization_enabled: true}'
   ```

   Your `~/.dbt/profiles.yml` profile needs a `dev` target (or add
   `--target <name>` matching whatever your profile actually calls it).

3. **Compile, so the board's `ref()` calls have a manifest to resolve
   against**, from the repo root:

   ```bash
   dbt compile
   ```

   Re-run this any time the package's models change or get rebuilt -
   `target/manifest.json` is a snapshot, not live.

4. **Launch the dashboard**, from the repo root:

   ```bash
   dct validate charts/cost_optimization_overview.yml
   dct serve
   ```

   `dct serve` prints the URL it's bound to (defaults to
   `http://localhost:8501/cost_optimization_overview/`). To render a static
   snapshot instead of serving live:

   ```bash
   dct render charts/cost_optimization_overview.yml --format html --output /tmp/my_preview.html
   ```

The board reads exclusively via `ref()` now, so it always reflects whatever
schema your own `dbt build` materialized into - there's no schema/database
to find-and-replace, and no shared trainer schema to grant access to.
