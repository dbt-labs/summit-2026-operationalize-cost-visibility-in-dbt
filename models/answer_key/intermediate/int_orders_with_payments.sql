-- Order grain enriched with payment behavior. One row per order.
--
-- OPTIMIZED ANSWER KEY:
-- Aggregate each lower-grain input to order grain first, then join the rollups
-- back to orders. This avoids the order_items x payments fanout and keeps the
-- query shape aligned to the final grain.

{{
    config(
        materialized='table'
    )
}}

with orders as (
    select * from {{ ref('stg_abra_pos__orders') }}
),

order_items as (
    select * from {{ ref('stg_abra_pos__order_items') }}
),

payments as (
    select * from {{ ref('stg_abra_pos__payments') }}
),

item_totals as (
    select
        order_id,
        count(*) as line_item_count,
        sum(quantity) as total_quantity,
        sum(line_revenue_copper) as gross_revenue_copper,
        sum(line_revenue_gold) as gross_revenue_gold
    from order_items
    group by order_id
),

payment_rollup as (
    select
        order_id,
        sum(case when payment_status = 'success' then amount_gold else 0 end) as amount_paid_gold,
        count(*) as payment_attempt_count,
        sum(case when payment_status = 'success' then 1 else 0 end) as successful_payment_count,
        max(case when payment_status = 'failed' then 1 else 0 end) = 1 as had_failed_attempt,
        max(case when payment_status = 'refunded' then 1 else 0 end) = 1 as is_refunded,
        max(paid_at) as last_paid_at
    from payments
    group by order_id
),

final as (
    select
        -- ids
        orders.order_id,
        orders.customer_id,
        orders.shop_id,

        -- attributes
        orders.order_status,
        orders.channel,

        -- measures
        coalesce(item_totals.line_item_count, 0) as line_item_count,
        coalesce(item_totals.total_quantity, 0) as total_quantity,
        coalesce(item_totals.gross_revenue_gold, 0) as gross_revenue_gold,
        orders.discount_gold,
        coalesce(item_totals.gross_revenue_gold, 0) - orders.discount_gold as net_revenue_gold,
        coalesce(payment_rollup.amount_paid_gold, 0) as amount_paid_gold,

        -- payment behavior flags
        coalesce(payment_rollup.successful_payment_count, 0) > 1 as is_split_payment,
        coalesce(payment_rollup.had_failed_attempt, false) as had_failed_attempt,
        coalesce(payment_rollup.is_refunded, false) as is_refunded,

        -- timestamps
        orders.ordered_at,
        payment_rollup.last_paid_at
    from orders
    left join item_totals on orders.order_id = item_totals.order_id
    left join payment_rollup on orders.order_id = payment_rollup.order_id
)

select * from final
