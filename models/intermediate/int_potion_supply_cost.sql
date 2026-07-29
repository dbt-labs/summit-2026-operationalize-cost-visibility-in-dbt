-- Cost to brew one unit of each potion, rolled up from its recipe.
--
-- DESIGN DECISION: recipe quantities and ingredient unit costs are expressed in
-- mixed units (gram / vial / pinch / …). A fully correct model would convert to
-- a common unit before costing. Here we make the simplifying assumption that
-- raw `quantity` multiplies raw `unit_cost` directly and document it explicitly.

with recipe as (
    select * from {{ ref('stg_alembic_ops__potion_ingredients') }}
),

ingredients as (
    select * from {{ ref('stg_alembic_ops__ingredients') }}
),

final as (
    select
        recipe.potion_sku,
        count(*) as ingredient_count,
        sum(recipe.quantity * ingredients.unit_cost_copper) as cost_to_brew_copper,
        {{ copper_to_gold('sum(recipe.quantity * ingredients.unit_cost_copper)') }} as cost_to_brew_gold
    from recipe
    inner join ingredients on recipe.ingredient_id = ingredients.ingredient_id
    group by recipe.potion_sku
)

select * from final
