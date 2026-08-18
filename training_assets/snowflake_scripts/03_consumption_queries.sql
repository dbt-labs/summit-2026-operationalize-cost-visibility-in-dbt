----------------------------------------------------------------------
-- 1. QUERIES AGAINST DIM_WIZARDS
----------------------------------------------------------------------

-- For unoptimized models

-- Query 1: guild_tier_customer_value
with base as (
    select
        customer_id,
        order_id,
        ordered_date,
        net_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_orders
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
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.guild_name,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by total_net_revenue_gold desc, guild_name, membership_tier;

-- Query 2: membership_payment_outcomes
with base as (
    select
        customer_id,
        payment_status,
        paid_date,
        amount_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_payments
    where paid_date between '2026-04-01' and '2026-06-30'
),

final as (
    select
        wizards.membership_tier,
        wizards.is_guild_member,
        base.payment_status,
        count(*) as payment_attempt_count,
        sum(base.amount_gold) as total_payment_amount_gold
    from base
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.membership_tier,
        wizards.is_guild_member,
        base.payment_status
)

select * from final
order by is_guild_member desc, membership_tier, payment_status;

-- Query 3: monthly_shop_membership_sales
with base as (
    select
        shop_id,
        customer_id,
        ordered_date,
        quantity,
        line_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items
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
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards as wizards
        on base.customer_id = wizards.customer_id
    group by
        base.shop_id,
        order_month,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by order_month desc, shop_id, is_guild_member desc, membership_tier;

-- Query 4: regional_discipline_order_mix
with base as (
    select
        customer_id,
        channel,
        ordered_date,
        net_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_orders
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
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.home_region,
        wizards.favored_discipline,
        base.channel
)

select * from final
order by total_net_revenue_gold desc, home_region, favored_discipline, channel;

-- Query 5: regulated_potion_member_mix
with base as (
    select
        order_items.shop_id,
        order_items.customer_id,
        order_items.potion_sku,
        order_items.ordered_date,
        order_items.quantity,
        order_items.line_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items as order_items
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
    inner join apothecaries.dbt_jstayton_costs_marts.dim_potions as potions
        on base.potion_sku = potions.potion_sku
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards as wizards
        on base.customer_id = wizards.customer_id
    where potions.is_regulated
    group by
        base.shop_id,
        wizards.home_region,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by regulated_revenue_gold desc, shop_id, home_region, membership_tier;


-- For optimized models

-- Query 1: guild_tier_customer_value
with base as (
    select
        customer_id,
        order_id,
        ordered_date,
        net_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_orders__optimized
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
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards__optimized as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.guild_name,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by total_net_revenue_gold desc, guild_name, membership_tier;

-- Query 2: membership_payment_outcomes
with base as (
    select
        customer_id,
        payment_status,
        paid_date,
        amount_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_payments
    where paid_date between '2026-04-01' and '2026-06-30'
),

final as (
    select
        wizards.membership_tier,
        wizards.is_guild_member,
        base.payment_status,
        count(*) as payment_attempt_count,
        sum(base.amount_gold) as total_payment_amount_gold
    from base
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards__optimized as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.membership_tier,
        wizards.is_guild_member,
        base.payment_status
)

select * from final
order by is_guild_member desc, membership_tier, payment_status;

-- Query 3: monthly_shop_membership_sales
with base as (
    select
        shop_id,
        customer_id,
        ordered_date,
        quantity,
        line_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items__optimized
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
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards__optimized as wizards
        on base.customer_id = wizards.customer_id
    group by
        base.shop_id,
        order_month,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by order_month desc, shop_id, is_guild_member desc, membership_tier;

-- Query 4: regional_discipline_order_mix
with base as (
    select
        customer_id,
        channel,
        ordered_date,
        net_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_orders__optimized
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
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards__optimized as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.home_region,
        wizards.favored_discipline,
        base.channel
)

select * from final
order by total_net_revenue_gold desc, home_region, favored_discipline, channel;

-- Query 5: regulated_potion_member_mix
with base as (
    select
        order_items.shop_id,
        order_items.customer_id,
        order_items.potion_sku,
        order_items.ordered_date,
        order_items.quantity,
        order_items.line_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items__optimized as order_items
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
    inner join apothecaries.dbt_jstayton_costs_marts.dim_potions as potions
        on base.potion_sku = potions.potion_sku
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards__optimized as wizards
        on base.customer_id = wizards.customer_id
    where potions.is_regulated
    group by
        base.shop_id,
        wizards.home_region,
        wizards.membership_tier,
        wizards.is_guild_member
)

select * from final
order by regulated_revenue_gold desc, shop_id, home_region, membership_tier;


----------------------------------------------------------------------
-- 2. QUERIES AGAINST FCT_ORDER_ITEMS
----------------------------------------------------------------------

-- For unoptimized models

-- Query 1: daily_regulated_sales
with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.order_id,
        order_items.quantity,
        order_items.line_revenue_gold,
        potions.is_regulated
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items as order_items
    left join apothecaries.dbt_jstayton_costs_marts.dim_potions as potions
        on order_items.potion_sku = potions.potion_sku
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
      and potions.is_regulated
),

final as (
    select
        shop_id,
        ordered_date,
        count(distinct order_id) as regulated_order_count,
        sum(quantity) as regulated_units,
        sum(line_revenue_gold) as regulated_revenue_gold
    from base
    group by shop_id, ordered_date
)

select * from final
order by ordered_date desc, shop_id;

-- Query 2: daily_shop_sales
with base as (
    select
        order_id,
        shop_id,
        ordered_date,
        quantity,
        line_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items
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
order by ordered_date desc, shop_id;

-- Query 3: shop_category_mix
with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.order_id,
        order_items.quantity,
        order_items.line_revenue_gold,
        potions.category
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items as order_items
    left join apothecaries.dbt_jstayton_costs_marts.dim_potions as potions
        on order_items.potion_sku = potions.potion_sku
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
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
order by ordered_date desc, shop_id, category;

-- Query 4: shop_customer_basket
with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.customer_id,
        order_items.order_id,
        order_items.quantity,
        order_items.line_revenue_gold,
        wizards.is_guild_member
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items as order_items
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards as wizards
        on order_items.customer_id = wizards.customer_id
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
),

customer_day_rollup as (
    select
        shop_id,
        ordered_date,
        customer_id,
        max(is_guild_member) as is_guild_member,
        count(distinct order_id) as order_count,
        sum(quantity) as total_units,
        sum(line_revenue_gold) as total_line_revenue_gold
    from base
    group by shop_id, ordered_date, customer_id
),

final as (
    select
        shop_id,
        ordered_date,
        is_guild_member,
        count(*) as customer_count,
        avg(order_count)::number(38, 2) as avg_orders_per_customer,
        avg(total_units)::number(38, 2) as avg_units_per_customer,
        avg(total_line_revenue_gold)::number(38, 2) as avg_revenue_per_customer
    from customer_day_rollup
    group by shop_id, ordered_date, is_guild_member
)

select * from final
order by ordered_date desc, shop_id, is_guild_member desc;

-- Query 5: top_skus_by_shop
with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.potion_sku,
        order_items.quantity,
        order_items.line_revenue_gold,
        potions.potion_name
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items as order_items
    left join apothecaries.dbt_jstayton_costs_marts.dim_potions as potions
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
order by shop_id, revenue_rank;


-- For optimized models

-- Query 1: daily_regulated_sales
with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.order_id,
        order_items.quantity,
        order_items.line_revenue_gold,
        potions.is_regulated
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items__optimized as order_items
    left join apothecaries.dbt_jstayton_costs_marts.dim_potions as potions
        on order_items.potion_sku = potions.potion_sku
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
      and potions.is_regulated
),

final as (
    select
        shop_id,
        ordered_date,
        count(distinct order_id) as regulated_order_count,
        sum(quantity) as regulated_units,
        sum(line_revenue_gold) as regulated_revenue_gold
    from base
    group by shop_id, ordered_date
)

select * from final
order by ordered_date desc, shop_id;

-- Query 2: daily_shop_sales
with base as (
    select
        order_id,
        shop_id,
        ordered_date,
        quantity,
        line_revenue_gold
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items__optimized
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
order by ordered_date desc, shop_id;

-- Query 3: shop_category_mix
with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.order_id,
        order_items.quantity,
        order_items.line_revenue_gold,
        potions.category
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items__optimized as order_items
    left join apothecaries.dbt_jstayton_costs_marts.dim_potions as potions
        on order_items.potion_sku = potions.potion_sku
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
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
order by ordered_date desc, shop_id, category;

-- Query 4: shop_customer_basket
with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.customer_id,
        order_items.order_id,
        order_items.quantity,
        order_items.line_revenue_gold,
        wizards.is_guild_member
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items__optimized as order_items
    left join apothecaries.dbt_jstayton_costs_marts.dim_wizards__optimized as wizards
        on order_items.customer_id = wizards.customer_id
    where order_items.ordered_date between '2026-04-01' and '2026-06-30'
      and order_items.shop_id in ('SHP-01', 'SHP-04', 'SHP-09', 'SHP-14')
),

customer_day_rollup as (
    select
        shop_id,
        ordered_date,
        customer_id,
        max(is_guild_member) as is_guild_member,
        count(distinct order_id) as order_count,
        sum(quantity) as total_units,
        sum(line_revenue_gold) as total_line_revenue_gold
    from base
    group by shop_id, ordered_date, customer_id
),

final as (
    select
        shop_id,
        ordered_date,
        is_guild_member,
        count(*) as customer_count,
        avg(order_count)::number(38, 2) as avg_orders_per_customer,
        avg(total_units)::number(38, 2) as avg_units_per_customer,
        avg(total_line_revenue_gold)::number(38, 2) as avg_revenue_per_customer
    from customer_day_rollup
    group by shop_id, ordered_date, is_guild_member
)

select * from final
order by ordered_date desc, shop_id, is_guild_member desc;

-- Query 5: top_skus_by_shop
with base as (
    select
        order_items.shop_id,
        order_items.ordered_date,
        order_items.potion_sku,
        order_items.quantity,
        order_items.line_revenue_gold,
        potions.potion_name
    from apothecaries.dbt_jstayton_costs_marts.fct_order_items__optimized as order_items
    left join apothecaries.dbt_jstayton_costs_marts.dim_potions as potions
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
order by shop_id, revenue_rank;
