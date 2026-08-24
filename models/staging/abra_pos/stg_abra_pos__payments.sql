select
    -- ids
    payment_id,
    order_id,

    -- attributes
    lower(trim(method)) as payment_method,
    lower(trim(status)) as payment_status,

    -- money
    amount_copper::int as amount_copper,
    {{ copper_to_gold('amount_copper') }} as amount_gold,

    -- timestamps
    paid_at::timestamp_ntz as paid_at,
    ingested_at::timestamp_ntz as ingested_at
from {{ source('abra_pos', 'raw_payments') }}
