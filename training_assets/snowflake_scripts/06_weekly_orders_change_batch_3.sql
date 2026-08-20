-- Training script: fct_orders ingestion batch 3 of 3
--
-- Change mix (18 raw records):
--   - 4 new orders
--   - 7 order items for those orders
--   - 3 successful payments for those orders
--   - 2 corrections to historical order items
--   - 1 late failed payment and 1 late refund for other historical orders
--
-- Run after batch 2 and its model builds. Item and payment watermarks should
-- demonstrate that child-record changes update existing order-grain rows.

use database apothecaries;
use schema raw;

set workshop_batch_name = 'batch_3_item_corrections_and_late_payments';
set batch_ingested_at = current_timestamp()::timestamp_ntz;

create table if not exists fct_orders_workshop_batch_manifest (
    batch_name varchar,
    batch_ingested_at timestamp_ntz,
    raw_table varchar,
    record_id varchar,
    change_type varchar
);

create table if not exists fct_orders_workshop_order_backup (
    order_id varchar,
    status varchar,
    discount_copper varchar,
    ingested_at timestamp_ntz
);

create table if not exists fct_orders_workshop_order_item_backup (
    order_item_id varchar,
    quantity varchar,
    unit_price_copper varchar,
    ingested_at timestamp_ntz
);

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
    batch_order_number,
    'ORD-' || lpad(order_number::varchar, 9, '0') as order_id,
    max_order_item_number,
    max_payment_number
from new_orders
cross join maxima;

create or replace temporary table weekly_batch_order_items as
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
        (1, 1, 'POT-0008', '2', '950'),
        (2, 2, 'POT-0037', '1', '1825'),
        (2, 3, 'POT-0081', '2', '640'),
        (3, 4, 'POT-0049', '3', '715'),
        (3, 5, 'POT-0105', '1', '1430'),
        (4, 6, 'POT-0029', '2', '1095'),
        (4, 7, 'POT-0063', '5', '420')
) as definitions (
    batch_order_number,
    line_number,
    potion_sku,
    quantity,
    unit_price_copper
)
    on batch.batch_order_number = definitions.batch_order_number;

create or replace temporary table weekly_batch_payments as
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
        (1, 1, 'barter', '3010', '2026-08-25T07:58:00Z'),
        (3, 2, 'guild_credit', '3575', '2026-08-25 13:47:00'),
        (4, 3, 'coin', '4290', '2026-08-25T16:33:00Z')
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
    definitions.status,
    definitions.paid_at,
    $batch_ingested_at as ingested_at
from (
    select max(max_payment_number) as max_payment_number
    from weekly_batch_keys
) as batch
cross join (
    select * from values
        (4, 'ORD-000225002', 'barter', '900', 'failed', '2026-08-25 17:10:00'),
        (5, 'ORD-000275002', 'coin', '1250', 'refunded', '2026-08-25T18:05:00Z')
) as definitions (
    payment_number,
    order_id,
    method,
    amount_copper,
    status,
    paid_at
);

begin;

merge into fct_orders_workshop_order_item_backup as target
using (
    select order_item_id, quantity, unit_price_copper, ingested_at
    from raw_order_items
    where order_item_id in ('ITM-0000800005', 'ITM-0001000005')
) as source
on target.order_item_id = source.order_item_id
when not matched then insert (
    order_item_id,
    quantity,
    unit_price_copper,
    ingested_at
) values (
    source.order_item_id,
    source.quantity,
    source.unit_price_copper,
    source.ingested_at
);

insert into raw_orders (
    order_id,
    customer_id,
    shop_id,
    ordered_at,
    status,
    channel,
    discount_copper,
    ingested_at
)
select
    order_id,
    case batch_order_number
        when 1 then 'WIZ-00067890'
        when 2 then 'WIZ-00078901'
        when 3 then 'WIZ-00089012'
        when 4 then 'WIZ-00090123'
    end as customer_id,
    case batch_order_number
        when 1 then 'SHP-03'
        when 2 then 'SHP-06'
        when 3 then 'SHP-12'
        when 4 then 'SHP-14'
    end as shop_id,
    case batch_order_number
        when 1 then '2026-08-25T07:45:00Z'
        when 2 then '2026-08-25 10:20:00'
        when 3 then '2026-08-25T13:35:00Z'
        when 4 then '2026-08-25 16:15:00'
    end as ordered_at,
    'completed' as status,
    case batch_order_number
        when 1 then 'marketplace'
        when 2 then 'in_store'
        when 3 then 'courier_owl'
        when 4 then 'marketplace'
    end as channel,
    case batch_order_number
        when 1 then '75'
        when 4 then '225'
        else '0'
    end as discount_copper,
    $batch_ingested_at as ingested_at
from weekly_batch_keys;

insert into raw_order_items (
    order_item_id,
    order_id,
    potion_sku,
    quantity,
    unit_price_copper,
    ingested_at
)
select
    order_item_id,
    order_id,
    potion_sku,
    quantity,
    unit_price_copper,
    ingested_at
from weekly_batch_order_items;

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
    payment_id,
    order_id,
    method,
    amount_copper,
    status,
    paid_at,
    ingested_at
from weekly_batch_payments;

update raw_order_items
set
    quantity = case order_item_id
        when 'ITM-0000800005' then '5'
        when 'ITM-0001000005' then '2'
    end,
    unit_price_copper = case order_item_id
        when 'ITM-0000800005' then '1299'
        when 'ITM-0001000005' then '899'
    end,
    ingested_at = $batch_ingested_at
where order_item_id in ('ITM-0000800005', 'ITM-0001000005');

insert into fct_orders_workshop_batch_manifest (
    batch_name,
    batch_ingested_at,
    raw_table,
    record_id,
    change_type
)
select $workshop_batch_name, $batch_ingested_at, 'RAW_ORDERS', order_id, 'INSERT'
from weekly_batch_keys
union all
select $workshop_batch_name, $batch_ingested_at, 'RAW_ORDER_ITEMS', order_item_id, 'INSERT'
from weekly_batch_order_items
union all
select $workshop_batch_name, $batch_ingested_at, 'RAW_PAYMENTS', payment_id, 'INSERT'
from weekly_batch_payments
union all
select $workshop_batch_name, $batch_ingested_at, 'RAW_ORDER_ITEMS', column1, 'UPDATE'
from values ('ITM-0000800005'), ('ITM-0001000005');

commit;

select
    $workshop_batch_name as batch_name,
    $batch_ingested_at as batch_ingested_at,
    4 as expected_new_order_count,
    4 as expected_changed_existing_order_count,
    8 as expected_changed_order_count;
