{{ config(materialized='table') }}

-- Wizard (customer) dimension: one row per customer, enriched with their
-- current guild membership (if any). Guild fields are null for the ~35% of
-- wizards with no current membership.
--
-- OPTIMIZED ANSWER KEY:
-- Materialize this frequently queried dimensional surface as a table so
-- downstream reporting and marts read from a persisted result instead of
-- recomputing the enrichment logic on every query.

with customers as (
    select * from {{ ref('stg_grimoire_crm__customers') }}
),

memberships as (
    select * from {{ ref('int_memberships_current') }}
),

final as (
    select
        -- ids
        customers.customer_id::varchar as customer_id,

        -- attributes
        customers.full_name::varchar as full_name,
        customers.email::varchar as email,
        customers.home_region::varchar as home_region,
        customers.favored_discipline::varchar as favored_discipline,
        customers.birth_year::integer as birth_year,

        -- current guild membership (nullable)
        memberships.guild_id::varchar as guild_id,
        memberships.guild_name::varchar as guild_name,
        memberships.tier::varchar as membership_tier,
        (memberships.customer_id is not null)::boolean as is_guild_member,

        -- timestamps
        customers.signed_up_at::date as signed_up_at,
        memberships.member_since::date as member_since
    from customers
    left join memberships on customers.customer_id = memberships.customer_id
)

select * from final
