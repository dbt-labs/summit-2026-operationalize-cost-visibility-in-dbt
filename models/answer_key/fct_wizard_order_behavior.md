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
- cost and margin proxy logic

It also handles multiple grains inline, repeats work across CTEs, and builds the final customer-grain output by dragging lower-grain order, line, payment, and potion-cost data through one oversized query.

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
- roll up potion preferences and cost proxies once
- join those customer-grain results together in the final mart

That makes the grain explicit and keeps each model focused on one responsibility.

## How the fix was implemented

Before:

- one giant mart joined dimensions, order facts, line facts, payment facts, potion attributes, and potion-cost proxies together
- category ranking, behavioral rollups, and estimated cost/margin logic were computed inline
- lower-grain data was carried through most of the query plan

After:

- `int_wizard_order_behavior_base` handles customer-grain order and channel behavior
- `int_wizard_potion_preferences` handles customer-grain item/category preference logic plus estimated cost rollups
- `fct_wizard_order_behavior__optimized` assembles those two rollups into one presentation-ready customer behavior output and computes the final margin proxy
- the public `refunded_order_count`, `split_payment_order_count`, and channel order-count names remain stable; the optimized grain-aligned logic corrects values that are inflated by the starter model's fanout

## Expected benefit

Expected improvements from the optimized version:

- simpler query shape
- clearer grain transitions
- easier maintenance and debugging
- lower repeated compute from avoiding one oversized all-in-one query
- a more teachable and governable mart design

## How to compare before and after

During the workshop:

1. Give attendees the Jira-style symptoms, constraints, public columns, and customer-grain acceptance criteria.
2. Let them design focused intermediate rollups and a thin final mart without inspecting `models/answer_key/`.
3. Build the focal `fct_wizard_order_behavior` model and compare targeted runtime, rows through joins, and query shape with prepared starter evidence.
4. Debrief multiple valid architectures and annualize the observed cost difference.

After the workshop, compare the implementation with the trainer reference under `models/answer_key/intermediate/` and `models/answer_key/marts/`.


## Prevention takeaway

When a mart needs several different rollups at the same final grain, split them into intermediate models with explicit responsibilities instead of forcing all logic into one monster SQL file. In dbt, modularity is not just style — it is a performance and maintainability optimization.
