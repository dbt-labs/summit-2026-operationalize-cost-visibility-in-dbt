with base as (
    select
        customer_id,
        order_id,
        ordered_date,
        net_revenue_gold
    from {{ ref('fct_orders') }}
    where ordered_date between '2026-04-01' and '2026-06-30'
),

final as (
    select
        wizards.guild_name,
        wizards.membership_tier,
        wizards.is_guild_member,
        count(distinct base.customer_id) as customer_count,
        count(*) as order_count,
        sum(base.net_revenue_gold) as total_net_revenue_gold,
        avg(base.net_revenue_gold)::number(38, 2) as average_order_value_gold
    from base
    left join {{ ref('dim_wizards') }} as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.guild_name,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by total_net_revenue_gold desc, guild_name, membership_tier
