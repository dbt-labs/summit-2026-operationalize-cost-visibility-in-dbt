select
    -- ids
    shop_id,

    -- attributes
    shop_name,
    city,
    region, -- canonical spelling; conforms customers.home_region

    -- timestamps
    opened_at::date as opened_at
from {{ source('alembic_ops', 'raw_shops') }}
