{{ config(materialized='incremental', unique_key='order_id') }}

-- Order-grain fact. One row per order, with revenue/payment measures and
-- conformed FKs to the wizard, shop, and (via the shop) fulfilling region.
--
-- OPTIMIZED ANSWER KEY:
-- Convert the model to incremental so routine runs process only newly arrived
-- or recently changed orders instead of rebuilding the full fact every time.
--
-- FINAL PHASE-2 WORKSHOP STATE:
-- This version refines the incremental filter to capture changed historical
-- orders when late-arriving payment/refund activity updates order-level business
-- state. Instead of filtering only on recent ordered_at timestamps, it identifies
-- changed order_ids from the upstream intermediate.

with changed_orders as (
    {% if is_incremental() %}
        select order_id
        from {{ ref('int_orders_with_payments') }}
        where greatest(ordered_at, coalesce(last_paid_at, ordered_at)) >= (
            select coalesce(dateadd(day, -3, max(ordered_at)), '1900-01-01'::timestamp_ntz)
            from {{ this }}
        )
    {% else %}
        select cast(null as varchar) as order_id
        where false
    {% endif %}
),

orders as (
    select *
    from {{ ref('int_orders_with_payments') }}

    {% if is_incremental() %}
        where order_id in (select order_id from changed_orders)
    {% endif %}
),

shops as (
    select * from {{ ref('stg_alembic_ops__shops') }}
),

final as (
    select
        -- ids / fks
        orders.order_id::varchar as order_id,
        orders.customer_id::varchar as customer_id,
        orders.shop_id::varchar as shop_id,
        shops.region::varchar as fulfillment_region,

        -- attributes
        orders.order_status::varchar as order_status,
        orders.channel::varchar as channel,

        -- measures
        orders.line_item_count::integer as line_item_count,
        orders.total_quantity::integer as total_quantity,
        orders.gross_revenue_gold::number(38, 2) as gross_revenue_gold,
        orders.discount_gold::number(38, 2) as discount_gold,
        orders.net_revenue_gold::number(38, 2) as net_revenue_gold,
        orders.amount_paid_gold::number(38, 2) as amount_paid_gold,

        -- payment behavior flags
        orders.is_split_payment::boolean as is_split_payment,
        orders.had_failed_attempt::boolean as had_failed_attempt,
        orders.is_refunded::boolean as is_refunded,

        -- timestamps
        orders.ordered_at::timestamp_ntz as ordered_at,
        orders.ordered_at::date as ordered_date
    from orders
    left join shops on orders.shop_id = shops.shop_id
)

select * from final
