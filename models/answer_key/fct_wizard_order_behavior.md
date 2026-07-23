# fct_wizard_order_behavior

## Symptom

The customer behavior mart is slow, hard to reason about, and expensive to maintain because too many responsibilities are packed into one large SQL model.

## Root cause

The bad-state version mixes multiple concerns in a single mart:

- customer attributes
- order behavior
- payment behavior
- item-level potion preferences
- category ranking logic

It also handles multiple grains inline, repeats work across CTEs, and builds the final customer-grain output by dragging lower-grain order, line, and payment data through one oversized query.

## How the issue was identified

This pattern is identified by looking for:

- a very large model with many CTEs and mixed responsibilities
- repeated joins and repeated business logic in one file
- model SQL that is hard to explain in terms of a single clear grain transition
- expensive query shape caused by carrying lower-grain data too far downstream

## Optimization applied

The optimized version splits the logic into two customer-grain intermediate models plus one final mart:

- `int_wizard_order_behavior_base`
- `int_wizard_potion_preferences`
- `fct_wizard_order_behavior`

## Why this fix was the right one

This model is fundamentally a customer-grain behavior mart. The cleanest implementation is to:

- roll up order/payment behavior once
- roll up potion preferences once
- join those customer-grain results together in the final mart

That makes the grain explicit and keeps each model focused on one responsibility.

## How the fix was implemented

Before:

- one giant mart joined dimensions, order facts, line facts, payment facts, and potion attributes together
- category ranking and behavioral rollups were computed inline
- lower-grain data was carried through most of the query plan

After:

- `int_wizard_order_behavior_base` handles customer-grain order and channel behavior
- `int_wizard_potion_preferences` handles customer-grain item/category preference logic
- the final mart assembles those two rollups into one presentation-ready customer behavior output

## Expected benefit

Expected improvements from the optimized version:

- simpler query shape
- clearer grain transitions
- easier maintenance and debugging
- lower repeated compute from avoiding one oversized all-in-one query
- a more teachable and governable mart design

## How to compare before and after

1. Build the bad-state version from `models/marts/fct_wizard_order_behavior.sql`.
2. Review the SQL shape and note how many responsibilities are packed into one file.
3. Compare to the answer-key split across `models/answer_key/intermediate/` and `models/answer_key/marts/`.
4. Confirm that the optimized version uses explicit customer-grain rollups before the final assembly step.
5. Compare maintainability and explainability alongside runtime/query-shape improvements.

## Prevention takeaway

When a mart needs several different rollups at the same final grain, split them into intermediate models with explicit responsibilities instead of forcing all logic into one monster SQL file. In dbt, modularity is not just style — it is a performance and maintainability optimization.
