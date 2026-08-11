with base as (
    select
        shop_id,
        customer_id,
        ordered_date,
        quantity,
        line_revenue_gold
    from {{ ref('fct_order_items') }}
    where ordered_date between '2026-04-01' and '2026-06-30'
      and shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
),

final as (
    select
        base.shop_id,
        date_trunc('month', base.ordered_date)::date as order_month,
        wizards.membership_tier,
        wizards.is_guild_member,
        sum(base.quantity) as total_units,
        sum(base.line_revenue_gold) as total_line_revenue_gold
    from base
    left join {{ ref('dim_wizards') }} as wizards
        on base.customer_id = wizards.customer_id
    group by
        base.shop_id,
        order_month,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by order_month desc, shop_id, is_guild_member desc, membership_tier
