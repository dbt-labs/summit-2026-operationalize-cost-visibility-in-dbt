# Demo 05: refactor the customer behavior mart

## Audience outcome

Attendees can turn a performance-oriented Jira ticket into a modular dbt design, make grain transitions explicit, preserve a public mart interface, and connect targeted runtime evidence to annualized cost.

## Timing and interaction

- **Current planning budget:** 35 minutes; validate during the dry run.
- **Mode:** independent main lab followed by architecture and cost debrief.
- **Attendee artifact:** focused customer-grain intermediate logic feeding a thin `fct_wizard_order_behavior` mart.

## Setup and prerequisites

- Demo 04 established the native-grain alignment rule.
- The opening build created the starter `fct_wizard_order_behavior`.
- The trainer has starter query profiles, targeted build timing, and a stable reference implementation.
- Existing mart tests and public column expectations are known.
- An annualized cost worksheet is ready.

## Jira-style ticket

### Summary

Refactor `fct_wizard_order_behavior` to reduce unnecessary lower-grain processing and make the customer-grain responsibilities maintainable without changing its public output.

### Symptoms

- The model is approximately 185 lines and mixes customer, order, payment, item, potion, ranking, cost, and margin logic.
- Lower-grain rows are carried through most of the plan.
- Payment attempts can multiply item rows.
- Revenue and order flags are repeated across line/payment combinations.
- The query is slow to build, hard to review, and expensive to modify safely.

### Constraints

- Final grain remains one row per `customer_id`.
- Preserve the existing public column names and types.
- Correct order-count metrics at order grain; do not preserve fanout-inflated values.
- Preserve customer rows with no qualifying orders or potion activity.
- Reuse existing `ref()` inputs and project conventions.
- Put reusable rollups under `models/intermediate/`.
- Do not inspect `models/answer_key/` during implementation.

### Acceptance criteria

- Order/payment behavior is rolled up to customer grain once.
- Potion preference and supply-cost behavior is rolled up to customer grain once.
- The final mart joins compatible customer-grain inputs and handles presentation defaults.
- Favorite-category ranking remains deterministic.
- Existing public mart tests pass.
- Targeted build evidence shows less unnecessary join/aggregation work or a defensible architecture improvement with an explicit cost hypothesis.

## Facilitator flow

### 1. Issue the ticket and inspect the symptom — 5 minutes

Walk through the starter profile and model shape without designing the solution for the room. Refer back to Demo 04:

> We already know how to stop a native-grain fanout. Apply that rule here, then decide where model responsibilities should separate.

Clarify outputs and constraints. Avoid reteaching join grain.

### 2. Independent design and implementation — 18 minutes

Attendees sketch the intended grain of each new model before coding, then implement.

Useful coaching questions:

- Which metrics depend only on orders?
- Which depend on item and potion attributes?
- Where should payment behavior enter?
- At what point is each CTE/model guaranteed to be one row per customer?
- Which logic is reusable enough to deserve an intermediate?
- Does persisting an intermediate add value, or is the project-default ephemeral materialization sufficient?

The reference design uses two customer-grain intermediates and a thin final mart, but alternative decompositions are acceptable when they preserve grain, output, and evidence requirements.

### 3. Targeted validation — 4 minutes

For intermediates that inherit the project-default ephemeral materialization:

```text
dbt build --select fct_wizard_order_behavior --full-refresh
```

If an attendee deliberately persists a new intermediate, include that model in the selector so it is built before the mart.

### 4. Architecture debrief — 5 minutes

Invite two or three attendees to describe their boundaries and grain guarantees. Compare them with the trainer reference at a conceptual level:

- customer order/payment behavior;
- customer potion preference/cost behavior; and
- thin final assembly.

Discuss where each approach reduces rows, repeated work, and maintenance risk.

### 5. Cost debrief — 3 minutes

Compare targeted before/after evidence and annualize:

```text
annual savings = (before credits - after credits) × runs per year
```

If credits are unavailable, use warehouse-seconds as a clearly labeled proxy and keep warehouse size constant.

## Decision checkpoint

Ask:

> Which model boundary in your design provides the strongest performance guarantee, and what evidence proves it?

Good answers name an explicit customer-grain rollup and support it with row counts, join profiles, bytes processed, or targeted runtime—not only readability.

## Validation and evidence

Required:

- one row per customer;
- existing public columns and types preserved;
- required customer population preserved;
- order counts calculated from order-grain data;
- favorite category remains deterministic;
- mart tests pass; and
- focal build completes.

Capture:

- targeted before/after build time;
- rows through major joins and aggregates;
- bytes scanned and spill;
- relation write work;
- model execution frequency; and
- projected annual cost difference.

## Cost and governance framing

A contract can protect names and types, and tests can protect selected assumptions. Neither automatically proves that the implementation avoided fanout or unnecessary work. Weak validation can let an expensive query shape become a stable public interface.

The prevention mechanism is a combination of explicit model grain, focused responsibilities, high-value tests, code review, and profile-aware performance evidence.

## Common failures and recovery

- **Public columns disappear:** compare the pre-edit column list and restore every non-targeted field.
- **New intermediates are persisted but not selected:** build them explicitly before the mart.
- **Customer rows disappear:** inspect the final join direction and null defaults.
- **Order counts remain inflated:** trace their source back to order grain.
- **Favorite category is unstable:** add a deterministic tie-breaker.
- **Room does not finish:** stop at the design checkpoint, use the trainer reference for debrief, and preserve the unfinished branch as part of the take-home comparison.

## Transition

> We’ve optimized individual models and model boundaries. The last cost surface is orchestration: deciding what dbt should build, test, defer, or reuse on each run.
