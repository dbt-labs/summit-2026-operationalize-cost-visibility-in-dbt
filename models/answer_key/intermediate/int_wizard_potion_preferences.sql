-- Customer-grain potion preference rollup based on order lines and potion attributes.

with order_items as (
    select * from {{ ref('fct_order_items') }}
),

potions as (
    select * from {{ ref('dim_potions') }}
),

item_enriched as (
    select
        order_items.customer_id,
        order_items.order_item_id,
        order_items.quantity,
        potions.category,
        potions.is_regulated
    from order_items
    left join potions on order_items.potion_sku = potions.potion_sku
),

category_counts as (
    select
        customer_id,
        category,
        count(*) as category_line_count,
        row_number() over (partition by customer_id order by count(*) desc, category asc) as category_rank
    from item_enriched
    group by customer_id, category
),

favorite_category as (
    select
        customer_id,
        category as favorite_potion_category
    from category_counts
    where category_rank = 1
),

preference_rollup as (
    select
        customer_id,
        sum(quantity) as total_units_purchased,
        sum(case when is_regulated then 1 else 0 end) as regulated_potion_line_count
    from item_enriched
    group by customer_id
),

final as (
    select
        preference_rollup.customer_id,
        coalesce(preference_rollup.total_units_purchased, 0) as total_units_purchased,
        favorite_category.favorite_potion_category,
        coalesce(preference_rollup.regulated_potion_line_count, 0) as regulated_potion_line_count
    from preference_rollup
    left join favorite_category on preference_rollup.customer_id = favorite_category.customer_id
)

select * from final
