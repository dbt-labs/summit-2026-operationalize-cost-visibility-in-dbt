select
    -- ids
    brew_id,
    potion_sku,
    shop_id,
    cauldron_id,

    -- attributes
    lower(trim(quality_check)) as quality_check,
    brewer_name,

    -- measures
    batch_size::int as batch_size,
    brew_duration_minutes::int as brew_duration_minutes,

    -- timestamps
    brewed_at::timestamp_ntz as brewed_at
from {{ source('alembic_ops', 'raw_brew_events') }}
