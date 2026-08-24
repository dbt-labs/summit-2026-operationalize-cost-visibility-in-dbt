select
    -- ids
    customer_id,

    -- attributes
    full_name,
    nullif(trim(email), '') as email,
    {{ conform_region('home_region') }} as home_region,
    lower(trim(favored_discipline)) as favored_discipline,
    birth_year::int as birth_year,

    -- timestamps
    signed_up_at::date as signed_up_at
from {{ source('grimoire_crm', 'raw_customers') }}
