select
    -- ids
    order_id,
    customer_id,
    shop_id,

    -- attributes
    lower(trim(status)) as order_status,
    lower(trim(channel)) as channel,

    -- money
    discount_copper::int as discount_copper,
    {{ copper_to_gold('discount_copper') }} as discount_gold,

    -- timestamps
    ordered_at::timestamp_ntz as ordered_at,
    ingested_at::timestamp_ntz as ingested_at
from {{ source('abra_pos', 'raw_orders') }}
