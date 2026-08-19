-- One-time repair for the weekly batch loaded on 2026-08-19.
--
-- Repairs:
--   1. Keep one row for each refund duplicated by the former four-row cross join.
--   2. Remap the four new orders from seven-digit to valid eight-digit wizard IDs.
--
-- This script is idempotent for the listed payment and order IDs.

use database apothecaries;
use schema raw;

create or replace temporary table weekly_batch_payment_repair as
select
    payment_id,
    order_id,
    method,
    amount_copper,
    status,
    paid_at,
    ingested_at
from raw_payments
where payment_id in ('PAY-0150000001', 'PAY-0150000002')
qualify row_number() over (
    partition by payment_id
    order by ingested_at
) = 1;

begin;

delete from raw_payments
where payment_id in ('PAY-0150000001', 'PAY-0150000002');

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
from weekly_batch_payment_repair;

update raw_orders
set customer_id = case order_id
    when 'ORD-037500001' then 'WIZ-00000123'
    when 'ORD-037500002' then 'WIZ-00004567'
    when 'ORD-037500003' then 'WIZ-00008910'
    when 'ORD-037500004' then 'WIZ-00012345'
end
where order_id in (
    'ORD-037500001',
    'ORD-037500002',
    'ORD-037500003',
    'ORD-037500004'
);

commit;

-- Both validation queries should return zero rows.
select
    payment_id,
    count(*) as row_count
from raw_payments
where payment_id in ('PAY-0150000001', 'PAY-0150000002')
group by payment_id
having count(*) <> 1;

select
    orders.order_id,
    orders.customer_id
from raw_orders as orders
left join raw_customers as customers
    on orders.customer_id = customers.customer_id
where orders.order_id in (
    'ORD-037500001',
    'ORD-037500002',
    'ORD-037500003',
    'ORD-037500004'
)
    and customers.customer_id is null;
