with source as (
    select * from {{ source('abra_pos', 'raw_order_items') }}
),

renamed as (
    select
        -- ids
        order_item_id,
        order_id,
        potion_sku,

        -- measures
        quantity::int as quantity,
        unit_price_copper::int as unit_price_copper,
        {{ copper_to_gold('unit_price_copper') }} as unit_price_gold,

        -- operational metadata
        ingested_at::timestamp_ntz as ingested_at,

        -- line revenue at sale time (quantity * unit price)

        (quantity::int * unit_price_copper::int) as line_revenue_copper,
        {{ copper_to_gold('quantity::int * unit_price_copper::int') }} as line_revenue_gold
    from source
)

select * from renamed
