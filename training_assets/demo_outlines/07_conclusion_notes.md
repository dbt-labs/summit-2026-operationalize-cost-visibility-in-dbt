# Conclusion notes: interpreting the optimization results

This file is slide-ready wrap-up material for the deck. It is not an eighth workshop demo and does not add to the projected module timing.

## Slide 1: the observed whole-build result

### On-slide content

**Observed benchmark**

- Starter build: **3:13** / **193 seconds**
- Optimized build: **2:46** / **166 seconds**
- Time saved: **27 seconds**
- Runtime reduction: **14.0%**

### Calculation

```text
runtime reduction = (193 - 166) / 193
                  = 27 / 193
                  = 13.99%
                  ≈ 14.0%
```

### Speaker note

A 14% full-build improvement is real, but it is only one part of the cost story. The project build includes shared upstream models, tests, and work that remains unchanged in both versions.

## Slide 2: what that could mean at a larger scale

### On-slide content

**Illustrative 30-minute build**

- Original runtime: **30:00**
- Runtime after a 14% reduction: **25:48**
- Time saved per run: **4:12**

### Calculation

```text
30 minutes × (1 - 0.14) = 25.8 minutes
25.8 minutes = 25 minutes 48 seconds
30:00 - 25:48 = 4:12 saved per run
```

### Speaker note

This is a scale illustration, not a forecast. Warehouse concurrency, model count, caching, auto-suspend, data growth, and the critical path can prevent elapsed time from scaling linearly.

Do not convert the 4:12 directly into projected credits without a measured warehouse configuration and execution frequency.

## Slide 3: why the full-build improvement looks modest

### On-slide content

**The optimized build still performs shared work**

- Shared staging and supporting models remain.
- Tests still execute.
- Some optimizations move cost instead of removing it from the build.
- Full-build elapsed time is affected by parallelism and the critical path.
- Incremental savings are underrepresented by a one-time full refresh or first build.

### Speaker note

A whole-project timer blends multiple cost surfaces together. It is useful as a final integration check, but it can hide the value of an optimization that primarily benefits recurring model runs or downstream consumers.

## Slide 4: where each optimization pays back

### On-slide content

| Optimization | Primary cost surface | Expected value |
|---|---|---|
| Clustering `fct_order_items` | Consumption queries | Better pruning and fewer bytes scanned across repeated filtered reads |
| Persisting `dim_wizards` | Consumption queries | Avoid repeated view expansion and enrichment work |
| Incremental `fct_orders` | Recurring dbt builds | Scan and write only changed keys after target establishment |
| Grain-aligned order joins | Model build and downstream consumers | Carry fewer rows through joins and aggregations; avoid fanout |
| Modular customer mart | Model build, maintenance, and downstream trust | Reduce mixed-grain work and make expensive logic easier to reason about |
| dbt State and job scope | Orchestration | Avoid rebuilding and retesting unaffected resources |

### Speaker note

The project-wide build is not expected to show the full benefit of clustering or dimension persistence. Those changes are designed to reduce repeated read cost. Incremental processing is designed to improve normal recurring runs, not the initial target creation.

## Slide 5: the stronger ROI story

### On-slide content

**Use multiple evidence surfaces**

- Whole-project build runtime
- Focal-model runtime and bytes written
- Recurring incremental runtime
- Consumption-query bytes scanned
- Partitions scanned and pruning
- Rows entering expensive joins
- Query and job execution frequency
- Warehouse credits where available

### Speaker note

The right question is not only, “How much faster was the final build?” Ask, “Where did this optimization remove warehouse work, and how often is that work performed?”

## Slide 6: annualize at the correct grain

### On-slide content

```text
annual build savings
  = savings per recurring build × builds per year

annual query savings
  = savings per query × query executions per year

net annual savings
  = build savings + query savings - added maintenance cost
```

Added maintenance can include:

- table storage;
- clustering/reclustering work;
- scheduled refresh cost; and
- periodic incremental full refreshes or recovery.

### Speaker note

Keep warehouse size and measurement conditions stable. Prefer observed credits. If credits are unavailable, warehouse-seconds can be used as a clearly labeled proxy.

## Slide 7: optimization-specific interpretation

### Clustering

Clustering can make the model more expensive to write and maintain. Its value should appear in repeated filtered queries through improved pruning and fewer bytes scanned.

### Persisted dimension

Changing `dim_wizards` from a view to a table shifts compute into scheduled builds and adds storage. It pays back when many consumers avoid repeatedly recomputing the enrichment logic.

### Incremental orders

The first full refresh still processes all history. The value appears on recurring runs where a small changed-key set replaces a full historical scan and rewrite.

### Grain alignment

Aggregating lower-grain inputs before joining reduces the working row set. This can improve model runtime, downstream query shape, and correctness at the same time.

### Modular refactor

The performance result depends on where rollups occur and whether work is reused or repeated. Cleaner files alone are not evidence; use profile rows, bytes, spill, and targeted runtime.

### Jobs and State

SQL optimization cannot recover warehouse time spent rebuilding or retesting unaffected resources. Job selection, deferral, model reuse, and environment cleanup are part of the same cost system.

## Slide 8: recommended closing takeaway

### On-slide content

**Optimize at the cost surface where the work occurs.**

1. Diagnose with workload and execution evidence.
2. Match the dbt design to grain, ingestion, and consumption behavior.
3. Measure producer and consumer cost separately.
4. Annualize using real execution frequency.
5. Encode enough tests, job configuration, and review context to keep the waste from returning.

### Suggested closing narration

> The final build was about 14% faster, but that is not the complete return. Clustering and persistence reduce repeated consumption cost. Incremental processing reduces recurring scans and writes. Grain alignment removes unnecessary rows from the query plan. dbt State prevents unchanged work from running at all. The durable cost optimization comes from measuring each of those surfaces and matching the dbt design to how the data is built and consumed.

## Presenter cautions

- Describe the seven-module timing as the **current projected timing** until the dry run produces actual delivery times.
- Cut or compress material when rehearsal exceeds the workshop schedule.
- Do not present the 30-minute scale example as a guaranteed runtime or credit forecast.
- Keep before/after warehouse, source state, SQL, and cache assumptions comparable.
- Separate initial/full-refresh cost from recurring incremental cost.
- Include clustering, storage, and maintenance overhead in net savings.
- Use the 14.0% benchmark as one piece of evidence, not the headline proof for every optimization.
