-- Brew-batch-grain fact. One row per production batch. Joins the shop region
-- and an estimated batch supply cost (per-unit brew cost * batch size).

with brews as (
    select * from {{ ref('stg_alembic_ops__brew_events') }}
),

shops as (
    select * from {{ ref('stg_alembic_ops__shops') }}
),

supply_cost as (
    select * from {{ ref('int_potion_supply_cost') }}
),

final as (
    select
        -- ids / fks
        brews.brew_id::varchar as brew_id,
        brews.potion_sku::varchar as potion_sku,
        brews.shop_id::varchar as shop_id,
        shops.region::varchar as brew_region,
        brews.cauldron_id::varchar as cauldron_id,

        -- attributes
        brews.quality_check::varchar as quality_check,
        (brews.quality_check = 'pass')::boolean as passed_quality_check,
        brews.brewer_name::varchar as brewer_name,

        -- measures
        brews.batch_size::integer as batch_size,
        brews.brew_duration_minutes::integer as brew_duration_minutes,
        (supply_cost.cost_to_brew_gold * brews.batch_size)::number(38, 2) as batch_supply_cost_gold,

        -- timestamps
        brews.brewed_at::timestamp_ntz as brewed_at,
        brews.brewed_at::date as brewed_date
    from brews
    left join shops on brews.shop_id = shops.shop_id
    left join supply_cost on brews.potion_sku = supply_cost.potion_sku
)

select * from final
