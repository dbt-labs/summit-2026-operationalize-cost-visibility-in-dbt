select
    -- ids
    potion_sku,

    -- attributes
    potion_name,
    lower(trim(category)) as category,
    potency::int as potency,
    shelf_life_days::int as shelf_life_days,
    {{ to_boolean('is_regulated') }} as is_regulated,

    -- money
    base_price_copper::int as base_price_copper,
    {{ copper_to_gold('base_price_copper') }} as base_price_gold,

    -- timestamps
    introduced_at::date as introduced_at
from {{ source('abra_pos', 'raw_potions') }}
