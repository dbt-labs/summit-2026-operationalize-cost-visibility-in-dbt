with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.customer_id,
        order_items.order_id,
        order_items.quantity,
        order_items.line_revenue_gold,
        wizards.is_guild_member
    from {{ ref('fct_order_items') }} as order_items
    left join {{ ref('dim_wizards') }} as wizards
        on order_items.customer_id = wizards.customer_id
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
),

customer_day_rollup as (
    select
        shop_id,
        ordered_date,
        customer_id,
        max(is_guild_member) as is_guild_member,
        count(distinct order_id) as order_count,
        sum(quantity) as total_units,
        sum(line_revenue_gold) as total_line_revenue_gold
    from base
    group by shop_id, ordered_date, customer_id
),

final as (
    select
        shop_id,
        ordered_date,
        is_guild_member,
        count(*) as customer_count,
        avg(order_count)::number(38, 2) as avg_orders_per_customer,
        avg(total_units)::number(38, 2) as avg_units_per_customer,
        avg(total_line_revenue_gold)::number(38, 2) as avg_revenue_per_customer
    from customer_day_rollup
    group by shop_id, ordered_date, is_guild_member
)

select * from final
order by ordered_date desc, shop_id, is_guild_member desc
