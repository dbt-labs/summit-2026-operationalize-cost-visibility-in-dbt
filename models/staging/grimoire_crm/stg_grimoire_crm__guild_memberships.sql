select
    -- ids
    membership_id,
    customer_id,
    guild_id,

    -- attributes
    lower(trim(tier)) as tier,

    -- scd2 validity window; valid_to null (empty in raw) = current row
    valid_from::date as valid_from,
    nullif(trim(valid_to), '')::date as valid_to,
    (nullif(trim(valid_to), '') is null) as is_current
from {{ source('grimoire_crm', 'raw_guild_memberships') }}
