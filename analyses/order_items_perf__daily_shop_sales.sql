with base as (
    select
        order_id,
        shop_id,
        ordered_date,
        quantity,
        line_revenue_gold
    from {{ ref('fct_order_items') }}
    where ordered_date between '2026-04-01' and '2026-06-30'
      and shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
),

final as (
    select
        shop_id,
        ordered_date,
        count(distinct order_id) as order_count,
        sum(quantity) as total_units,
        sum(line_revenue_gold) as total_line_revenue_gold
    from base
    group by shop_id, ordered_date
)

select * from final
order by ordered_date desc, shop_id
