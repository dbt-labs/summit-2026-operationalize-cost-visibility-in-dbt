-- Training script: weekly fct_orders change batch
--
-- Purpose:
-- Simulate a small weekly source delivery against a large historical order fact.
-- The batch is intentionally small so the fct_orders merge incremental can show
-- that warehouse work should scale with changed order IDs, not total history.
--
-- Change mix (18 raw records total):
--   - 4 new orders
--   - 7 order items for those new orders
--   - 3 successful payments for those new orders
--   - 2 updates to existing orders
--   - 2 late payment/refund events for older existing orders
--
-- Every affected source record receives the same batch_ingested_at watermark.
-- New IDs are allocated above the current maximum IDs in the raw tables, so
-- each weekly run appends four genuinely new orders. The fixed historical
-- corrections make the changed-key merge behavior visible on every run.
--
-- Run weekly before the daily fct_orders build. The answer-key incremental
-- model should insert the four new order IDs and update the four changed
-- historical order IDs.

use database apothecaries;
use schema raw;

set batch_ingested_at = current_timestamp()::timestamp_ntz;

begin;

create or replace temporary table weekly_batch_keys as
with maxima as (
    select
        (select coalesce(max(try_to_number(regexp_substr(order_id, '\\d+$'))), 0) from raw_orders) as max_order_number,
        (select coalesce(max(try_to_number(regexp_substr(order_item_id, '\\d+$'))), 0) from raw_order_items) as max_order_item_number,
        (select coalesce(max(try_to_number(regexp_substr(payment_id, '\\d+$'))), 0) from raw_payments) as max_payment_number
),
new_orders as (
    select
        row_number() over (order by seq4()) as batch_order_number,
        max_order_number + row_number() over (order by seq4()) as order_number
    from maxima,
    table(generator(rowcount => 4))
)
select
    batch_order_number as batch_order_number,
    'ORD-' || lpad(order_number::varchar, 9, '0') as order_id,
    max_order_item_number as max_order_item_number,
    max_payment_number as max_payment_number
from new_orders
cross join maxima;

-- Four new orders with dynamically allocated IDs.
merge into raw_orders as target
using (
    select
        order_id,
        case batch_order_number
            when 1 then 'WIZ-00000123'
            when 2 then 'WIZ-00004567'
            when 3 then 'WIZ-00008910'
            when 4 then 'WIZ-00012345'
        end as customer_id,
        case batch_order_number
            when 1 then 'SHP-04'
            when 2 then 'SHP-01'
            when 3 then 'SHP-13'
            when 4 then 'SHP-09'
        end as shop_id,
        case batch_order_number
            when 1 then '2026-08-11T09:15:00Z'
            when 2 then '2026-08-11 10:22:11'
            when 3 then '2026-08-11T11:44:26Z'
            when 4 then '2026-08-11 13:31:52'
        end as ordered_at,
        'completed' as status,
        case batch_order_number
            when 1 then 'in_store'
            when 2 then 'courier_owl'
            when 3 then 'marketplace'
            when 4 then 'in_store'
        end as channel,
        case batch_order_number
            when 1 then '100'
            when 3 then '200'
            else '0'
        end as discount_copper,
        $batch_ingested_at as ingested_at
    from weekly_batch_keys
) as source (
    order_id,
    customer_id,
    shop_id,
    ordered_at,
    status,
    channel,
    discount_copper,
    ingested_at
)
on target.order_id = source.order_id
when not matched then insert (
    order_id,
    customer_id,
    shop_id,
    ordered_at,
    status,
    channel,
    discount_copper,
    ingested_at
) values (
    source.order_id,
    source.customer_id,
    source.shop_id,
    source.ordered_at,
    source.status,
    source.channel,
    source.discount_copper,
    source.ingested_at
);

-- Seven new line items for the four new orders.
insert into raw_order_items (
    order_item_id,
    order_id,
    potion_sku,
    quantity,
    unit_price_copper,
    ingested_at
)
select
    'ITM-' || lpad((batch.max_order_item_number + definitions.line_number)::varchar, 10, '0') as order_item_id,
    batch.order_id,
    definitions.potion_sku,
    definitions.quantity,
    definitions.unit_price_copper,
    $batch_ingested_at as ingested_at
from weekly_batch_keys as batch
inner join (
    select * from values
        (1, 1, 'POT-0026', '2', '861'),
        (1, 2, 'POT-0003', '1', '455'),
        (2, 3, 'POT-0004', '1', '1591'),
        (2, 4, 'POT-0003', '2', '504'),
        (3, 5, 'POT-0059', '1', '1029'),
        (3, 6, 'POT-0034', '1', '719'),
        (4, 7, 'POT-0016', '4', '445')
) as definitions (
    batch_order_number,
    line_number,
    potion_sku,
    quantity,
    unit_price_copper
)
    on batch.batch_order_number = definitions.batch_order_number;

-- Three payments for new orders plus two late refunds for historical orders.
insert into raw_payments (
    payment_id,
    order_id,
    method,
    amount_copper,
    status,
    paid_at,
    ingested_at
)
select
    'PAY-' || lpad((batch.max_payment_number + definitions.payment_number)::varchar, 10, '0') as payment_id,
    batch.order_id,
    definitions.method,
    definitions.amount_copper,
    'success' as status,
    definitions.paid_at,
    $batch_ingested_at as ingested_at
from weekly_batch_keys as batch
inner join (
    select * from values
        (1, 1, 'guild_credit', '2077', '2026-08-11T09:27:00Z'),
        (2, 2, 'coin', '2308', '2026-08-11 10:31:11'),
        (3, 3, 'crystal_transfer', '1748', '2026-08-11T11:58:26Z')
) as definitions (
    batch_order_number,
    payment_number,
    method,
    amount_copper,
    paid_at
)
    on batch.batch_order_number = definitions.batch_order_number

union all

select
    'PAY-' || lpad((batch.max_payment_number + definitions.payment_number)::varchar, 10, '0') as payment_id,
    definitions.order_id,
    definitions.method,
    definitions.amount_copper,
    'refunded' as status,
    definitions.paid_at,
    $batch_ingested_at as ingested_at
from (
    select max(max_payment_number) as max_payment_number
    from weekly_batch_keys
) as batch
cross join (
    select * from values
        (4, 'ORD-000025000', 'coin', '403', '2026-08-11 14:14:47'),
        (5, 'ORD-000075000', 'guild_credit', '4754', '2026-08-11T14:45:32Z')
) as definitions (
    payment_number,
    order_id,
    method,
    amount_copper,
    paid_at
);

-- Corrections to existing orders; both are deliberately outside the new-order range.
update raw_orders
set
    discount_copper = case order_id
        when 'ORD-000050000' then '275'
        when 'ORD-000100000' then '0'
    end,
    status = case order_id
        when 'ORD-000050000' then 'returned'
        when 'ORD-000100000' then 'completed'
    end,
    ingested_at = $batch_ingested_at
where order_id in ('ORD-000050000', 'ORD-000100000');

commit;

-- Expected changed parent orders: 8 total.
select
    $batch_ingested_at as batch_ingested_at,
    4 as expected_new_order_count,
    4 as expected_changed_existing_order_count,
    8 as expected_changed_order_count;
