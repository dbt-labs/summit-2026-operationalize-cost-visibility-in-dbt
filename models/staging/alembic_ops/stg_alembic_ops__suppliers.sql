select
    -- ids
    supplier_id,

    -- attributes
    supplier_name,
    region,
    reliability_rating::int as reliability_rating,

    -- timestamps
    contracted_since::date as contracted_since
from {{ source('alembic_ops', 'raw_suppliers') }}
