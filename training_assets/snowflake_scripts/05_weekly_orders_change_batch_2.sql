-- Training script: fct_orders ingestion batch 2 of 3
--
-- Change mix (18 raw records):
--   - 4 new orders
--   - 7 order items for those orders
--   - 3 successful payments for those orders
--   - 2 corrections to historical orders
--   - 1 late refund and 1 late successful payment for other historical orders
--
-- Run after batch 1 and its model builds. The shared watermark should produce
-- four inserts and four historical-key updates in fct_orders__optimized.

use database apothecaries;
use schema raw;

set workshop_batch_name = 'batch_2_orders_and_late_payments';
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
        (1, 1, 'POT-0011', '1', '775'),
        (1, 2, 'POT-0068', '3', '540'),
        (2, 3, 'POT-0042', '2', '1190'),
        (3, 4, 'POT-0074', '1', '875'),
        (3, 5, 'POT-0099', '2', '1325'),
        (4, 6, 'POT-0021', '4', '390'),
        (4, 7, 'POT-0055', '1', '1660')
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
        (1, 1, 'coin', '2395', '2026-08-18 08:41:00'),
        (2, 2, 'guild_credit', '2380', '2026-08-18T10:06:00Z'),
        (4, 3, 'crystal_transfer', '3220', '2026-08-18 15:12:00')
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
        (4, 'ORD-000125002', 'coin', '650', 'refunded', '2026-08-18T16:20:00Z'),
        (5, 'ORD-000175002', 'crystal_transfer', '1800', 'success', '2026-08-18 17:05:00')
) as definitions (
    payment_number,
    order_id,
    method,
    amount_copper,
    status,
    paid_at
);

begin;

merge into fct_orders_workshop_order_backup as target
using (
    select order_id, status, discount_copper, ingested_at
    from raw_orders
    where order_id in ('ORD-000125000', 'ORD-000150000')
) as source
on target.order_id = source.order_id
when not matched then insert (
    order_id,
    status,
    discount_copper,
    ingested_at
) values (
    source.order_id,
    source.status,
    source.discount_copper,
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
        when 1 then 'WIZ-00023456'
        when 2 then 'WIZ-00034567'
        when 3 then 'WIZ-00045678'
        when 4 then 'WIZ-00056789'
    end as customer_id,
    case batch_order_number
        when 1 then 'SHP-02'
        when 2 then 'SHP-07'
        when 3 then 'SHP-11'
        when 4 then 'SHP-15'
    end as shop_id,
    case batch_order_number
        when 1 then '2026-08-18 08:30:00'
        when 2 then '2026-08-18T09:55:00Z'
        when 3 then '2026-08-18 12:10:00'
        when 4 then '2026-08-18T15:00:00Z'
    end as ordered_at,
    'completed' as status,
    case batch_order_number
        when 1 then 'courier_owl'
        when 2 then 'in_store'
        when 3 then 'marketplace'
        when 4 then 'courier_owl'
    end as channel,
    case batch_order_number
        when 2 then '150'
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

update raw_orders
set
    discount_copper = case order_id
        when 'ORD-000125000' then '125'
        when 'ORD-000150000' then '0'
    end,
    status = case order_id
        when 'ORD-000125000' then 'completed'
        when 'ORD-000150000' then 'cancelled'
    end,
    ingested_at = $batch_ingested_at
where order_id in ('ORD-000125000', 'ORD-000150000');

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
select $workshop_batch_name, $batch_ingested_at, 'RAW_ORDERS', column1, 'UPDATE'
from values ('ORD-000125000'), ('ORD-000150000');

commit;

select
    $workshop_batch_name as batch_name,
    $batch_ingested_at as batch_ingested_at,
    4 as expected_new_order_count,
    4 as expected_changed_existing_order_count,
    8 as expected_changed_order_count;
