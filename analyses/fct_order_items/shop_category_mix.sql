with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.order_id,
        order_items.quantity,
        order_items.line_revenue_gold,
        potions.category
    from {{ ref('fct_order_items') }} as order_items
    left join {{ ref('dim_potions') }} as potions
        on order_items.potion_sku = potions.potion_sku
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
),

final as (
    select
        shop_id,
        ordered_date,
        category,
        count(distinct order_id) as order_count,
        sum(quantity) as total_units,
        sum(line_revenue_gold) as total_line_revenue_gold
    from base
    group by shop_id, ordered_date, category
)

select * from final
order by ordered_date desc, shop_id, category
