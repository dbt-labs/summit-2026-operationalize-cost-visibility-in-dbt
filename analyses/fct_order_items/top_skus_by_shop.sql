with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.potion_sku,
        order_items.quantity,
        order_items.line_revenue_gold,
        potions.potion_name
    from {{ ref('fct_order_items') }} as order_items
    left join {{ ref('dim_potions') }} as potions
        on order_items.potion_sku = potions.potion_sku
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
),

sku_rollup as (
    select
        shop_id,
        potion_sku,
        max(potion_name) as potion_name,
        sum(quantity) as total_units,
        sum(line_revenue_gold) as total_line_revenue_gold
    from base
    group by shop_id, potion_sku
),

ranked as (
    select
        shop_id,
        potion_sku,
        potion_name,
        total_units,
        total_line_revenue_gold,
        row_number() over (partition by shop_id order by total_line_revenue_gold desc, potion_sku asc) as revenue_rank
    from sku_rollup
)

select * from ranked
where revenue_rank <= 10
order by shop_id, revenue_rank
