-- Training script: late-arriving update demo batch
--
-- Purpose:
-- Add new payment/refund-related source events tied to EXISTING order_ids so
-- attendees can see why naive incremental logic may miss changed historical
-- business state or cause unnecessary churn.
--
-- Primary demos supported:
-- - fct_orders: naive incremental logic vs improved change detection
-- - write amplification / churn follow-on discussion
--
-- Trainer instructions:
-- 1. Run this script only after the base dataset has already been loaded.
-- 2. Prefer running it after attendees have seen the clean append-only batch.
-- 3. Have attendees rebuild the relevant downstream models and compare outputs.
-- 4. Use 03_reset_demo_state.sql before the next session if you need to restore baseline.
--
-- Design principle:
-- - Prefer INSERTING new source events tied to existing order_ids.
-- - Avoid mutating old raw rows in place unless there is a very specific teaching reason.
--
-- Good candidate scenarios:
-- - refunded payment event arrives later for an existing order
-- - failed payment attempt arrives before a later success event
-- - split payment behavior becomes visible with additional payment rows

use database apothecaries;
use schema raw;

begin;

insert into raw_payments (
    payment_id,
    order_id,
    method,
    amount_copper,
    status,
    paid_at
)
values
    ('PAY-095101', 'ORD-074995', 'coin', 403, 'refunded', '2026-07-03 09:14:47'),
    ('PAY-095102', 'ORD-074996', 'guild_credit', 4754, 'refunded', '2026-07-03T10:45:32Z'),
    ('PAY-095103', 'ORD-074998', 'coin', 15265, 'refunded', '2026-07-03 11:18:51'),
    ('PAY-095104', 'ORD-074994', 'crystal_transfer', 1842, 'refunded', '2026-07-03T12:22:50Z');

commit;
