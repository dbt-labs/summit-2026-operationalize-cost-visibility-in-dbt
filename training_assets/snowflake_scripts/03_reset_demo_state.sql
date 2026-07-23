-- Training script: reset shared source data back to baseline
--
-- Purpose:
-- Remove trainer-added demo rows from the shared raw source tables so the
-- workshop can be reset cleanly between sessions.
--
-- Primary demos supported:
-- - all incremental/churn demos that rely on trainer-inserted source events
--
-- Trainer instructions:
-- 1. Run this script after a session or before a dry run if demo rows are present.
-- 2. Keep the delete predicates tightly scoped to the known demo records.
-- 3. Verify row counts after reset so the base training dataset is restored.
--
-- Safety guidance:
-- - Never use unbounded deletes in the shared source schema.
-- - This script is keyed to explicit demo record IDs.
-- - Update this script whenever 01_append_orders_batch.sql or 02_late_payment_updates.sql changes.

use database apothecaries;
use schema raw;

begin;

delete from raw_payments
where payment_id in (
    'PAY-095001',
    'PAY-095002',
    'PAY-095003',
    'PAY-095004',
    'PAY-095005',
    'PAY-095006',
    'PAY-095101',
    'PAY-095102',
    'PAY-095103',
    'PAY-095104'
);

delete from raw_order_items
where order_item_id in (
    'ITM-290001',
    'ITM-290002',
    'ITM-290003',
    'ITM-290004',
    'ITM-290005',
    'ITM-290006',
    'ITM-290007',
    'ITM-290008',
    'ITM-290009',
    'ITM-290010'
);

delete from raw_orders
where order_id in (
    'ORD-090001',
    'ORD-090002',
    'ORD-090003',
    'ORD-090004',
    'ORD-090005'
);

commit;
