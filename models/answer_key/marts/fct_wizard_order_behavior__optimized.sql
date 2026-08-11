{{ config(materialized='table') }}

-- Customer behavior mart for commercial/lifecycle analysis.
--
-- OPTIMIZED ANSWER KEY:
-- Split the customer behavior mart into clear customer-grain intermediates so
-- the final mart assembles presentation fields instead of recomputing every
-- behavioral feature inline.

with behavior_base as (
    select * from {{ ref('int_wizard_order_behavior_base') }}
),

potion_preferences as (
    select * from {{ ref('int_wizard_potion_preferences') }}
),

final as (
    select
        behavior_base.customer_id::varchar as customer_id,
        behavior_base.full_name::varchar as full_name,
        behavior_base.home_region::varchar as home_region,
        behavior_base.guild_name::varchar as guild_name,
        behavior_base.membership_tier::varchar as membership_tier,
        behavior_base.is_guild_member::boolean as is_guild_member,
        behavior_base.first_order_at::timestamp_ntz as first_order_at,
        behavior_base.latest_order_at::timestamp_ntz as latest_order_at,
        behavior_base.days_since_last_order::integer as days_since_last_order,
        behavior_base.lifetime_order_count::integer as lifetime_order_count,
        behavior_base.lifetime_net_revenue_gold::number(38, 2) as lifetime_net_revenue_gold,
        behavior_base.average_order_value_gold::number(38, 2) as average_order_value_gold,
        coalesce(potion_preferences.total_units_purchased, 0)::integer as total_units_purchased,
        potion_preferences.favorite_potion_category::varchar as favorite_potion_category,
        coalesce(potion_preferences.regulated_potion_line_count, 0)::integer as regulated_potion_line_count,
        coalesce(potion_preferences.estimated_total_supply_cost_gold, 0)::number(38, 2) as estimated_total_supply_cost_gold,
        (behavior_base.lifetime_net_revenue_gold - coalesce(potion_preferences.estimated_total_supply_cost_gold, 0))::number(38, 2) as estimated_gross_margin_gold,
        coalesce(potion_preferences.high_cost_potion_line_count, 0)::integer as high_cost_potion_line_count,
        behavior_base.refunded_order_count::integer as refunded_order_count,
        behavior_base.split_payment_order_count::integer as split_payment_order_count,
        behavior_base.marketplace_order_count::integer as marketplace_order_count,
        behavior_base.courier_order_count::integer as courier_order_count,
        behavior_base.in_store_order_count::integer as in_store_order_count
    from behavior_base
    left join potion_preferences on behavior_base.customer_id = potion_preferences.customer_id
)

select * from final
