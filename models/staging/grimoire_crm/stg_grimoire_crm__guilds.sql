select
    -- ids
    guild_id,

    -- attributes
    guild_name,
    founded_year::int as founded_year
from {{ source('grimoire_crm', 'raw_guilds') }}
