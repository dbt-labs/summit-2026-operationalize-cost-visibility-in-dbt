# dim_wizards

## Symptom

Queries and downstream models that rely on `dim_wizards` take longer than they should because a frequently accessed dimension is being recomputed at query time.

## Root cause

The bad-state version is materialized as a `view`. That means every downstream query has to re-run the customer and membership enrichment logic instead of reading from a persisted dimensional surface.

For a dimension that is reused often, this creates repeated compute cost with little benefit.

## How the issue was identified

This pattern is identified by looking for:

- commonly queried dimensions materialized as views
- dashboards or marts that repeatedly touch the same dimension logic
- query profiles showing repeated work on a dimension that changes relatively slowly

## Optimization applied

The optimized version materializes `dim_wizards` as a `table`.

That persists the enriched customer dimension and lets downstream consumers read a stable precomputed result instead of paying to recompute it every time.

## Why this fix was the right one

`dim_wizards` is a good candidate for persistence because:

- it is a dimension-style model used for repeated slicing and joins
- the enrichment logic is modest but reusable
- the data does not need to be virtualized at query time to stay correct

Persisting a frequently queried dimension is a straightforward way to reduce repeated compute.

## How the fix was implemented

Before:

- `dim_wizards` is materialized as `view`
- downstream queries re-run the enrichment logic each time

After:

- `dim_wizards` is materialized as `table`
- downstream queries read from a persisted dimensional surface

## Expected benefit

Expected improvements from the optimized version:

- faster repeated reads from BI and downstream marts
- less repeated warehouse compute
- simpler query profiles for consumers that join to the dimension

## How to compare before and after

During the workshop:

1. Run one representative `analyses/dim_wizards/` consumer against the starter view.
2. Review the profile and identify repeated customer/membership enrichment.
3. Change the starter model to a table and build only `dim_wizards`.
4. Run the exact same consumer again and compare the persisted read.

After the workshop, compare the attendee implementation with `models/answer_key/marts/dim_wizards__optimized.sql`.


## Prevention takeaway

Not every model should be a table, but frequently queried reusable dimensions are strong candidates for persistence. In dbt, choose materializations based on how the model is consumed, not just how easy it is to define.
