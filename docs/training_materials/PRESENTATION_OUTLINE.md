# Presentation outline: cost optimization through dbt

This is the concise presenter-facing outline for mapping the repo to the workshop deck.

## Core workshop message

Using dbt correctly helps teams:

1. make queries run faster
2. make queries read less data

The workshop teaches this through symptom → diagnosis → fix → prevention.

## Optimization coverage

### Tier 1: highest-priority optimizations

These should get the most airtime.

#### 1. Unhealthy joins / exploding joins

- **Symptom:** long-running queries, inflated metrics, poor query shape
- **Model:** `models/intermediate/int_orders_with_payments.sql`
- **Answer key:** `models/answer_key/intermediate/int_orders_with_payments.sql`
- **Companion doc:** `models/answer_key/int_orders_with_payments.md`

#### 2. Full table rebuild instead of incremental

- **Symptom:** long-running builds, unnecessary compute on unchanged history
- **Model:** `models/marts/fct_orders.sql`
- **Answer key:** `models/answer_key/marts/fct_orders.sql`
- **Companion doc:** `models/answer_key/fct_orders.md`

#### 3. Incremental logic refinement for late-arriving changes

- **Symptom:** naive incremental logic misses changed historical business state or causes unnecessary churn
- **Model:** `models/marts/fct_orders.sql`
- **Answer key:** `models/answer_key/marts/fct_orders.sql`
- **Companion doc:** `models/answer_key/fct_orders.md`
- **Trainer data scripts:**
  - `training_assets/snowflake_scripts/01_append_orders_batch.sql`
  - `training_assets/snowflake_scripts/02_late_payment_updates.sql`
  - `training_assets/snowflake_scripts/03_reset_demo_state.sql`

#### 4. View instead of table for a frequently queried dimension

- **Symptom:** repeated downstream queries recompute the same dimension logic
- **Model:** `models/marts/dim_wizards.sql`
- **Answer key:** `models/answer_key/marts/dim_wizards.sql`
- **Companion doc:** `models/answer_key/dim_wizards.md`

#### 5. Modular refactor of oversized SQL

- **Symptom:** one giant mart is slow, hard to reason about, and hard to maintain
- **Bad-state model:** `models/marts/fct_wizard_order_behavior.sql`
- **Answer-key intermediates:**
  - `models/answer_key/intermediate/int_wizard_order_behavior_base.sql`
  - `models/answer_key/intermediate/int_wizard_potion_preferences.sql`
- **Answer-key mart:** `models/answer_key/marts/fct_wizard_order_behavior.sql`
- **Companion doc:** `models/answer_key/fct_wizard_order_behavior.md`
- **Teaching note:** this lab now includes a light estimated cost/margin proxy via `int_potion_supply_cost` so the refactor story stays tied to spend-aware analysis without turning into a separate procurement module


### Tier 2: strong supporting optimization

#### 6. Pruning / clustering based on observed workload

- **Symptom:** repeated filtered queries scan too much data
- **Model:** `models/marts/fct_order_items.sql`
- **Answer key:** `models/answer_key/marts/fct_order_items.sql`
- **Companion doc:** `models/answer_key/fct_order_items.md`
- **Cluster keys:** `ordered_date`, `shop_id`
- **Workload analyses:**
  - `analyses/order_items_perf__daily_shop_sales.sql`
  - `analyses/order_items_perf__shop_category_mix.sql`
  - `analyses/order_items_perf__top_skus_by_shop.sql`
  - `analyses/order_items_perf__daily_regulated_sales.sql`
  - `analyses/order_items_perf__shop_customer_basket.sql`

### Tier 3: job and governance optimization

These are part of the workshop plan and repo docs, even where the dbt job configuration is the main teaching surface rather than a model file.

#### 7. Job scope optimization

- broad selectors vs purpose-built selectors
- deploy jobs vs CI jobs
- state and deferral
- slim CI
- indirect test selection
- CI cleanup for incremental validation

Primary planning docs:

- `docs/TRAINING_NOTES.md`
- `docs/jobs.md` (planned)

#### 8. Test scope optimization

- **Symptom:** jobs spend too much time and money running tests too broadly
- **Primary teaching surface:** job configuration and selector design
- **Related models:** marts in `models/marts/`, especially `fct_orders`, `fct_order_items`, and `dim_wizards`

## Recommended presentation order

### 1. Join health

Start with `int_orders_with_payments` because it is an easy symptom-to-fix story and teaches both correctness and performance.

### 2. Incremental materialization

Move to `fct_orders` full table rebuild vs incremental.

### 3. Incremental refinement

Stay on `fct_orders` and introduce late-arriving payment/refund changes.

### 4. Materialization strategy for dimensions

Use `dim_wizards` for the clean view-to-table story.

### 5. Modular refactor lab

Use `fct_wizard_order_behavior` for the architecture/design section.

### 6. Clustering / pruning

Use `fct_order_items` plus the five workload analyses.

### 7. Jobs and test scope

Close with CI/deploy/state/deferral/test selection.

## One-line mapping from optimization to model

| Optimization | Primary model / asset |
|---|---|
| Exploding join | `int_orders_with_payments` |
| Table → incremental | `fct_orders` |
| Incremental phase 2 / churn | `fct_orders` + trainer DML scripts |
| View → table | `dim_wizards` |
| Modular refactor | `fct_wizard_order_behavior` |
| Clustering / pruning | `fct_order_items` + `analyses/order_items_perf__*.sql` |
| Job scope optimization | dbt job configs + `docs/TRAINING_NOTES.md` |
| Test scope optimization | dbt job configs + marts in `models/marts/` |

## Presenter shortcut

If you need the fastest possible deck-planning summary:

1. `int_orders_with_payments` → bad joins
2. `fct_orders` → incremental
3. `fct_orders` again → better incremental logic for late-arriving changes
4. `dim_wizards` → persist a reused dim
5. `fct_wizard_order_behavior` → split a monster model into 2 ints + 1 mart
6. `fct_order_items` + analysis workload → cluster for pruning
7. jobs/selectors/tests/state/deferral → operational cost optimization
