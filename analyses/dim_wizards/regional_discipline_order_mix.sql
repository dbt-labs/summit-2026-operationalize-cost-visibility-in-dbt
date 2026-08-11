with base as (
    select
        customer_id,
        channel,
        ordered_date,
        net_revenue_gold
    from {{ ref('fct_orders') }}
    where ordered_date between '2026-04-01' and '2026-06-30'
),

final as (
    select
        wizards.home_region,
        wizards.favored_discipline,
        base.channel,
        count(*) as order_count,
        sum(base.net_revenue_gold) as total_net_revenue_gold
    from base
    left join {{ ref('dim_wizards') }} as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.home_region,
        wizards.favored_discipline,
        base.channel
)

select * from final
order by total_net_revenue_gold desc, home_region, favored_discipline, channel
