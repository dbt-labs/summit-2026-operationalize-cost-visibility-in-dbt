with source as (
    select * from {{ source('alembic_ops', 'raw_ingredients') }}
),

renamed as (
    select
        -- ids
        ingredient_id,
        supplier_id,

        -- attributes
        ingredient_name,
        lower(trim(unit)) as unit,
        lower(trim(harvest_season)) as harvest_season,
        {{ to_boolean('is_hazardous') }} as is_hazardous,

        -- money
        unit_cost_copper::int as unit_cost_copper,
        {{ copper_to_gold('unit_cost_copper') }} as unit_cost_gold
    from source
)

select * from renamed
