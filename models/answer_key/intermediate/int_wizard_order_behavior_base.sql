-- Customer-grain behavioral rollup based on orders.

with wizards as (
    select * from {{ ref('dim_wizards') }}
),

orders as (
    select * from {{ ref('fct_orders') }}
),

order_rollup as (
    select
        customer_id,
        min(ordered_at) as first_order_at,
        max(ordered_at) as latest_order_at,
        count(distinct order_id) as lifetime_order_count,
        sum(net_revenue_gold) as lifetime_net_revenue_gold,
        avg(net_revenue_gold) as average_order_value_gold,
        sum(case when is_refunded then 1 else 0 end) as refunded_order_count,
        sum(case when is_split_payment then 1 else 0 end) as split_payment_order_count,
        sum(case when channel = 'marketplace' then 1 else 0 end) as marketplace_order_count,
        sum(case when channel = 'courier_owl' then 1 else 0 end) as courier_order_count,
        sum(case when channel = 'in_store' then 1 else 0 end) as in_store_order_count
    from orders
    group by customer_id
),

final as (
    select
        wizards.customer_id,
        wizards.full_name,
        wizards.home_region,
        wizards.guild_name,
        wizards.membership_tier,
        wizards.is_guild_member,
        order_rollup.first_order_at,
        order_rollup.latest_order_at,
        datediff(day, order_rollup.latest_order_at::date, current_date) as days_since_last_order,
        coalesce(order_rollup.lifetime_order_count, 0) as lifetime_order_count,
        coalesce(order_rollup.lifetime_net_revenue_gold, 0)::number(38, 2) as lifetime_net_revenue_gold,
        coalesce(order_rollup.average_order_value_gold, 0)::number(38, 2) as average_order_value_gold,
        coalesce(order_rollup.refunded_order_count, 0) as refunded_order_count,
        coalesce(order_rollup.split_payment_order_count, 0) as split_payment_order_count,
        coalesce(order_rollup.marketplace_order_count, 0) as marketplace_order_count,
        coalesce(order_rollup.courier_order_count, 0) as courier_order_count,
        coalesce(order_rollup.in_store_order_count, 0) as in_store_order_count
    from wizards
    left join order_rollup on wizards.customer_id = order_rollup.customer_id
)

select * from final
