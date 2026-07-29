{{ config(materialized='table') }}

-- Customer behavior mart for commercial/lifecycle analysis.
--
-- INTENTIONALLY BAD FOR TRAINING:
-- This model is a rushed all-in-one mart that mixes customer, order, payment,
-- potion-preference, and cost/margin proxy logic in a single query. It repeats
-- work, handles multiple grains inline, and is deliberately harder to reason
-- about than it should be.

with wizards as (
    select * from {{ ref('dim_wizards') }}
),

orders as (
    select * from {{ ref('fct_orders') }}
),

order_items as (
    select * from {{ ref('fct_order_items') }}
),

payments as (
    select * from {{ ref('fct_payments') }}
),

potions as (
    select * from {{ ref('dim_potions') }}
),

potion_cost as (
    select * from {{ ref('int_potion_supply_cost') }}
),

customer_orders as (
    select
        wizards.customer_id,
        wizards.full_name,
        wizards.home_region,
        wizards.guild_name,
        wizards.membership_tier,
        wizards.is_guild_member,
        orders.order_id,
        orders.order_status,
        orders.channel,
        orders.ordered_at,
        orders.net_revenue_gold,
        orders.is_split_payment,
        orders.had_failed_attempt,
        orders.is_refunded
    from wizards
    left join orders on wizards.customer_id = orders.customer_id
),

customer_order_lines as (
    select
        customer_orders.customer_id,
        customer_orders.full_name,
        customer_orders.home_region,
        customer_orders.guild_name,
        customer_orders.membership_tier,
        customer_orders.is_guild_member,
        customer_orders.order_id,
        customer_orders.order_status,
        customer_orders.channel,
        customer_orders.ordered_at,
        customer_orders.net_revenue_gold,
        customer_orders.is_split_payment,
        customer_orders.had_failed_attempt,
        customer_orders.is_refunded,
        order_items.order_item_id,
        order_items.potion_sku,
        order_items.quantity,
        order_items.line_revenue_gold
    from customer_orders
    left join order_items on customer_orders.order_id = order_items.order_id
),

customer_order_line_potions as (
    select
        customer_order_lines.customer_id,
        customer_order_lines.full_name,
        customer_order_lines.home_region,
        customer_order_lines.guild_name,
        customer_order_lines.membership_tier,
        customer_order_lines.is_guild_member,
        customer_order_lines.order_id,
        customer_order_lines.order_status,
        customer_order_lines.channel,
        customer_order_lines.ordered_at,
        customer_order_lines.net_revenue_gold,
        customer_order_lines.is_split_payment,
        customer_order_lines.had_failed_attempt,
        customer_order_lines.is_refunded,
        customer_order_lines.order_item_id,
        customer_order_lines.quantity,
        customer_order_lines.line_revenue_gold,
        potions.category,
        potions.is_regulated,
        coalesce(potion_cost.cost_to_brew_gold, 0) as estimated_unit_supply_cost_gold
    from customer_order_lines
    left join potions on customer_order_lines.potion_sku = potions.potion_sku
    left join potion_cost on customer_order_lines.potion_sku = potion_cost.potion_sku
),

customer_order_line_potion_payments as (
    select
        customer_order_line_potions.customer_id,
        customer_order_line_potions.full_name,
        customer_order_line_potions.home_region,
        customer_order_line_potions.guild_name,
        customer_order_line_potions.membership_tier,
        customer_order_line_potions.is_guild_member,
        customer_order_line_potions.order_id,
        customer_order_line_potions.order_status,
        customer_order_line_potions.channel,
        customer_order_line_potions.ordered_at,
        customer_order_line_potions.net_revenue_gold,
        customer_order_line_potions.is_split_payment,
        customer_order_line_potions.had_failed_attempt,
        customer_order_line_potions.is_refunded,
        customer_order_line_potions.order_item_id,
        customer_order_line_potions.quantity,
        customer_order_line_potions.line_revenue_gold,
        customer_order_line_potions.category,
        customer_order_line_potions.is_regulated,
        customer_order_line_potions.estimated_unit_supply_cost_gold,
        payments.payment_id,
        payments.payment_method,
        payments.payment_status,
        payments.amount_gold
    from customer_order_line_potions
    left join payments on customer_order_line_potions.order_id = payments.order_id
),

category_counts as (
    select
        customer_id,
        category,
        count(*) as category_line_count,
        row_number() over (partition by customer_id order by count(*) desc, category asc) as category_rank
    from customer_order_line_potion_payments
    group by customer_id, category
),

favorite_category as (
    select
        customer_id,
        category as favorite_potion_category
    from category_counts
    where category_rank = 1
),

final as (
    select
        customer_order_line_potion_payments.customer_id::varchar as customer_id,
        max(customer_order_line_potion_payments.full_name)::varchar as full_name,
        max(customer_order_line_potion_payments.home_region)::varchar as home_region,
        max(customer_order_line_potion_payments.guild_name)::varchar as guild_name,
        max(customer_order_line_potion_payments.membership_tier)::varchar as membership_tier,
        max(customer_order_line_potion_payments.is_guild_member)::boolean as is_guild_member,
        min(customer_order_line_potion_payments.ordered_at)::timestamp_ntz as first_order_at,
        max(customer_order_line_potion_payments.ordered_at)::timestamp_ntz as latest_order_at,
        datediff(day, max(customer_order_line_potion_payments.ordered_at)::date, current_date)::integer as days_since_last_order,
        count(distinct customer_order_line_potion_payments.order_id)::integer as lifetime_order_count,
        sum(customer_order_line_potion_payments.net_revenue_gold)::number(38, 2) as lifetime_net_revenue_gold,
        (sum(customer_order_line_potion_payments.net_revenue_gold) / nullif(count(distinct customer_order_line_potion_payments.order_id), 0))::number(38, 2) as average_order_value_gold,
        coalesce(sum(customer_order_line_potion_payments.quantity), 0)::integer as total_units_purchased,
        max(favorite_category.favorite_potion_category)::varchar as favorite_potion_category,
        count(case when customer_order_line_potion_payments.is_regulated then customer_order_line_potion_payments.order_item_id end)::integer as regulated_potion_line_count,
        coalesce(sum(customer_order_line_potion_payments.estimated_unit_supply_cost_gold * customer_order_line_potion_payments.quantity), 0)::number(38, 2) as estimated_total_supply_cost_gold,
        (sum(customer_order_line_potion_payments.net_revenue_gold) - coalesce(sum(customer_order_line_potion_payments.estimated_unit_supply_cost_gold * customer_order_line_potion_payments.quantity), 0))::number(38, 2) as estimated_gross_margin_gold,
        count(case when customer_order_line_potion_payments.estimated_unit_supply_cost_gold >= 30 then customer_order_line_potion_payments.order_item_id end)::integer as high_cost_potion_line_count,
        count(case when customer_order_line_potion_payments.is_refunded then customer_order_line_potion_payments.order_id end)::integer as refunded_order_row_count,
        count(case when customer_order_line_potion_payments.is_split_payment then customer_order_line_potion_payments.order_id end)::integer as split_payment_order_row_count,
        count(case when customer_order_line_potion_payments.channel = 'marketplace' then customer_order_line_potion_payments.order_id end)::integer as marketplace_order_row_count,
        count(case when customer_order_line_potion_payments.channel = 'courier_owl' then customer_order_line_potion_payments.order_id end)::integer as courier_order_row_count,
        count(case when customer_order_line_potion_payments.channel = 'in_store' then customer_order_line_potion_payments.order_id end)::integer as in_store_order_row_count
    from customer_order_line_potion_payments
    left join favorite_category on customer_order_line_potion_payments.customer_id = favorite_category.customer_id
    group by customer_order_line_potion_payments.customer_id
)

select * from final
