-- Training script: reset the fct_orders workshop source changes
--
-- Run once after all evidence collection is complete. This script:
--   1. deletes every insert recorded by batches 1-3, child tables first;
--   2. restores the original values of updated historical orders and items;
--   3. validates that the raw source is back to its pre-workshop state; and
--   4. clears the tracking tables for the next workshop session.
--
-- IMPORTANT: the optimized merge model does not propagate source hard deletes.
-- After this script, full-refresh the affected targets in separate commands:
--   dbt build --select +fct_orders --full-refresh
--   dbt build --select +fct_orders__optimized --full-refresh

use database apothecaries;
use schema raw;

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

begin;

-- Remove inserted children before their parent orders.
delete from raw_payments
where payment_id in (
    select record_id
    from fct_orders_workshop_batch_manifest
    where raw_table = 'RAW_PAYMENTS'
        and change_type = 'INSERT'
);

delete from raw_order_items
where order_item_id in (
    select record_id
    from fct_orders_workshop_batch_manifest
    where raw_table = 'RAW_ORDER_ITEMS'
        and change_type = 'INSERT'
);

delete from raw_orders
where order_id in (
    select record_id
    from fct_orders_workshop_batch_manifest
    where raw_table = 'RAW_ORDERS'
        and change_type = 'INSERT'
);

-- Restore the historical order values captured before the first mutation.
merge into raw_orders as target
using fct_orders_workshop_order_backup as source
on target.order_id = source.order_id
when matched then update set
    target.status = source.status,
    target.discount_copper = source.discount_copper,
    target.ingested_at = source.ingested_at;

-- Restore the historical item values captured before the first mutation.
merge into raw_order_items as target
using fct_orders_workshop_order_item_backup as source
on target.order_item_id = source.order_item_id
when matched then update set
    target.quantity = source.quantity,
    target.unit_price_copper = source.unit_price_copper,
    target.ingested_at = source.ingested_at;

commit;

-- Capture validation before clearing the control tables. All counts should be 0.
create or replace temporary table fct_orders_workshop_reset_validation as
select
    (
        select count(*)
        from raw_payments
        where payment_id in (
            select record_id
            from fct_orders_workshop_batch_manifest
            where raw_table = 'RAW_PAYMENTS'
                and change_type = 'INSERT'
        )
    )
    + (
        select count(*)
        from raw_order_items
        where order_item_id in (
            select record_id
            from fct_orders_workshop_batch_manifest
            where raw_table = 'RAW_ORDER_ITEMS'
                and change_type = 'INSERT'
        )
    )
    + (
        select count(*)
        from raw_orders
        where order_id in (
            select record_id
            from fct_orders_workshop_batch_manifest
            where raw_table = 'RAW_ORDERS'
                and change_type = 'INSERT'
        )
    ) as remaining_inserted_record_count,
    (
        select count(*)
        from fct_orders_workshop_order_backup as backup
        left join raw_orders as current
            on backup.order_id = current.order_id
        where current.order_id is null
            or not equal_null(current.status, backup.status)
            or not equal_null(current.discount_copper, backup.discount_copper)
            or not equal_null(current.ingested_at, backup.ingested_at)
    ) as order_backup_mismatch_count,
    (
        select count(*)
        from fct_orders_workshop_order_item_backup as backup
        left join raw_order_items as current
            on backup.order_item_id = current.order_item_id
        where current.order_item_id is null
            or not equal_null(current.quantity, backup.quantity)
            or not equal_null(current.unit_price_copper, backup.unit_price_copper)
            or not equal_null(current.ingested_at, backup.ingested_at)
    ) as order_item_backup_mismatch_count;

truncate table fct_orders_workshop_batch_manifest;
truncate table fct_orders_workshop_order_backup;
truncate table fct_orders_workshop_order_item_backup;

select * from fct_orders_workshop_reset_validation;
