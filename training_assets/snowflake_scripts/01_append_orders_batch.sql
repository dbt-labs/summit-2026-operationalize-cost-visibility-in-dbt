-- Training script: append-only incremental demo batch
--
-- Purpose:
-- Add brand-new source records to the shared raw tables so attendees can
-- rebuild incremental models and observe a clean append-only incremental run.
--
-- Primary demos supported:
-- - fct_orders: table -> incremental
-- - fct_orders: incremental correctness and runtime comparison
--
-- Trainer instructions:
-- 1. Run this script against the shared training source database/schema.
-- 2. Have attendees rebuild the relevant downstream models in their own schemas.
-- 3. Use 03_reset_demo_state.sql before the next session if you need to restore baseline.
--
-- Implementation notes:
-- - This script inserts NEW order_ids only.
-- - Every inserted order has matching order_items and payments.
-- - The row count is intentionally modest; this batch exists to trigger
--   incremental logic clearly, not to create the main performance delta.

use database apothecaries;
use schema raw;

begin;

insert into raw_orders (
    order_id,
    customer_id,
    shop_id,
    ordered_at,
    status,
    channel,
    discount_copper
)
values
    ('ORD-090001', 'WIZ-01891', 'SHP-04', '2026-07-02T09:15:00Z', 'completed', 'in_store', 100),
    ('ORD-090002', 'WIZ-10692', 'SHP-01', '2026-07-02 10:22:11', 'completed', 'courier_owl', 0),
    ('ORD-090003', 'WIZ-01925', 'SHP-13', '2026-07-02T11:44:26Z', 'completed', 'marketplace', 200),
    ('ORD-090004', 'WIZ-10922', 'SHP-14', '2026-07-02 12:08:39', 'completed', 'in_store', 0),
    ('ORD-090005', 'WIZ-05177', 'SHP-09', '2026-07-02T13:31:52Z', 'completed', 'courier_owl', 61);

insert into raw_order_items (
    order_item_id,
    order_id,
    potion_sku,
    quantity,
    unit_price_copper
)
values
    ('ITM-290001', 'ORD-090001', 'POT-0026', 2, 861),
    ('ITM-290002', 'ORD-090001', 'POT-0003', 1, 455),
    ('ITM-290003', 'ORD-090002', 'POT-0004', 1, 1591),
    ('ITM-290004', 'ORD-090002', 'POT-0003', 2, 504),
    ('ITM-290005', 'ORD-090003', 'POT-0059', 1, 1029),
    ('ITM-290006', 'ORD-090003', 'POT-0034', 1, 719),
    ('ITM-290007', 'ORD-090003', 'POT-0082', 3, 340),
    ('ITM-290008', 'ORD-090004', 'POT-0016', 4, 445),
    ('ITM-290009', 'ORD-090005', 'POT-0098', 2, 1521),
    ('ITM-290010', 'ORD-090005', 'POT-0034', 1, 719);

insert into raw_payments (
    payment_id,
    order_id,
    method,
    amount_copper,
    status,
    paid_at
)
values
    ('PAY-095001', 'ORD-090001', 'guild_credit', 2077, 'success', '2026-07-02T09:27:00Z'),
    ('PAY-095002', 'ORD-090002', 'coin', 1300, 'success', '2026-07-02 10:31:11'),
    ('PAY-095003', 'ORD-090002', 'coin', 1299, 'success', '2026-07-02T10:36:11Z'),
    ('PAY-095004', 'ORD-090003', 'crystal_transfer', 2568, 'success', '2026-07-02T11:58:26Z'),
    ('PAY-095005', 'ORD-090004', 'barter', 1780, 'success', '2026-07-02 12:22:39'),
    ('PAY-095006', 'ORD-090005', 'coin', 3700, 'success', '2026-07-02T13:44:52Z');

commit;
