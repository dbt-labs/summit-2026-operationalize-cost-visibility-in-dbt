with base as (
    select
        order_items.shop_id,
        order_items.customer_id,
        order_items.potion_sku,
        order_items.ordered_date,
        order_items.quantity,
        order_items.line_revenue_gold
    from {{ ref('fct_order_items') }} as order_items
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
),

final as (
    select
        base.shop_id,
        wizards.home_region,
        wizards.membership_tier,
        wizards.is_guild_member,
        sum(base.quantity) as regulated_units,
        sum(base.line_revenue_gold) as regulated_revenue_gold
    from base
    inner join {{ ref('dim_potions') }} as potions
        on base.potion_sku = potions.potion_sku
    left join {{ ref('dim_wizards') }} as wizards
        on base.customer_id = wizards.customer_id
    where potions.is_regulated
    group by
        base.shop_id,
        wizards.home_region,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by regulated_revenue_gold desc, shop_id, home_region, membership_tier
