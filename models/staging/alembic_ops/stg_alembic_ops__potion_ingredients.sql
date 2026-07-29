with source as (
    select * from {{ source('alembic_ops', 'raw_potion_ingredients') }}
),

renamed as (
    select
        -- ids
        {{ dbt_utils.generate_surrogate_key(['potion_sku', 'ingredient_id']) }} as recipe_id,
        potion_sku,
        ingredient_id,

        -- measures
        quantity::int as quantity,
        lower(trim(unit)) as unit
    from source
)

select * from renamed
