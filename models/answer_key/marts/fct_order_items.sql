{{ config(materialized='table', cluster_by=['ordered_date', 'shop_id']) }}

-- Line-grain fact. One row per potion per order. Carries the order date and
-- customer/shop FKs (denormalized from the order) for convenient slicing.
--
-- OPTIMIZED ANSWER KEY:
-- Cluster this large line-grain fact by the observed dashboard access pattern:
-- repeated filtering by ordered_date and shop_id.

with order_items as (
    select * from {{ ref('stg_abra_pos__order_items') }}
),

orders as (
    select * from {{ ref('stg_abra_pos__orders') }}
),

final as (
    select
        -- ids / fks
        order_items.order_item_id::varchar as order_item_id,
        order_items.order_id::varchar as order_id,
        order_items.potion_sku::varchar as potion_sku,
        orders.customer_id::varchar as customer_id,
        orders.shop_id::varchar as shop_id,

        -- measures
        order_items.quantity::integer as quantity,
        order_items.unit_price_gold::number(38, 2) as unit_price_gold,
        order_items.line_revenue_gold::number(38, 2) as line_revenue_gold,

        -- timestamps (from the parent order)
        orders.ordered_at::timestamp_ntz as ordered_at,
        orders.ordered_at::date as ordered_date
    from order_items
    inner join orders on order_items.order_id = orders.order_id
)

select * from final
