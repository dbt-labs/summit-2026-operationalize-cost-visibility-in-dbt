with suppliers as (
    select * from {{ ref('stg_alembic_ops__suppliers') }}
),

ingredients as (
    select * from {{ ref('stg_alembic_ops__ingredients') }}
),

ingredient_counts as (
    select
        supplier_id,
        count(*) as supplied_ingredient_count
    from ingredients
    group by supplier_id
),

final as (
    select
        suppliers.supplier_id::varchar as supplier_id,
        suppliers.supplier_name::varchar as supplier_name,
        suppliers.region::varchar as region,
        suppliers.reliability_rating::integer as reliability_rating,
        coalesce(ingredient_counts.supplied_ingredient_count, 0)::integer as supplied_ingredient_count,
        suppliers.contracted_since::date as contracted_since
    from suppliers
    left join ingredient_counts on suppliers.supplier_id = ingredient_counts.supplier_id
)

select * from final
