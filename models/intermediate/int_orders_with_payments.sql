-- Order grain enriched with payment behavior. One row per order.
--
-- INTENTIONALLY BAD FOR TRAINING:
-- This version joins orders, order_items, and payments at their native grains
-- and only aggregates after the fanout has already happened. It is useful for
-- demonstrating exploding joins, inflated metrics, and poor query shape.
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

joined as (
    select
        orders.order_id,
        orders.customer_id,
        orders.shop_id,
        orders.order_status,
        orders.channel,
        orders.discount_gold,
        orders.ordered_at,
        orders.ingested_at as order_ingested_at,
        order_items.order_item_id,
        order_items.quantity,
        order_items.line_revenue_copper,
        order_items.line_revenue_gold,
        order_items.ingested_at as order_item_ingested_at,
        payments.payment_id,
        payments.payment_method,
        payments.payment_status,
        payments.amount_gold,
        payments.paid_at,
        payments.ingested_at as payment_ingested_at
    from orders
    left join order_items on orders.order_id = order_items.order_id
    left join payments on orders.order_id = payments.order_id
),

final as (
    select
        -- ids
        order_id,
        customer_id,
        shop_id,

        -- attributes
        order_status,
        channel,

        -- measures
        count(order_item_id) as line_item_count,
        coalesce(sum(quantity), 0) as total_quantity,
        coalesce(sum(line_revenue_gold), 0) as gross_revenue_gold,
        discount_gold,
        coalesce(sum(line_revenue_gold), 0) - discount_gold as net_revenue_gold,
        coalesce(sum(case when payment_status = 'success' then amount_gold else 0 end), 0) as amount_paid_gold,

        -- payment behavior flags
        count(case when payment_status = 'success' then payment_id end) > 1 as is_split_payment,
        max(case when payment_status = 'failed' then 1 else 0 end) = 1 as had_failed_attempt,
        max(case when payment_status = 'refunded' then 1 else 0 end) = 1 as is_refunded,

        -- timestamps
        ordered_at,
        max(paid_at) as last_paid_at,
        greatest_ignore_nulls(
            max(order_ingested_at),
            max(order_item_ingested_at),
            max(payment_ingested_at)
        ) as source_updated_at
    from joined
    group by
        order_id,
        customer_id,
        shop_id,
        order_status,
        channel,
        discount_gold,
        ordered_at
)

select * from final
