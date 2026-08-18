-- ----------------------------------------------------------------------------
-- raw_customers
-- One row per customer. A small fraction of emails are null and home-region
-- values deliberately include source-system variations for staging to conform.
-- ----------------------------------------------------------------------------

create or replace table raw_customers as
select
    'WIZ-' || lpad((seq4() + 1)::varchar, 8, '0') as customer_id,
    'Wizard ' || (seq4() + 1)::varchar as full_name,
    case
        when mod(seq4(), 50) = 0 then null
        else 'wizard_' || (seq4() + 1)::varchar || '@merlinco.example'
    end as email,
    case mod(seq4(), 7)
        when 0 then 'Northern Reaches'
        when 1 then 'northern reaches'
        when 2 then 'Ember Coast'
        when 3 then 'ember_coast'
        when 4 then 'Silverwood'
        when 5 then 'The Marshlands'
        else 'Crystal Vale'
    end as home_region,
    case
        when mod(seq4(), 2) = 0
            then to_varchar(
                dateadd(day, -mod(abs(hash(seq4() + 1001)), 1095), current_timestamp()),
                'YYYY-MM-DD"T"HH24:MI:SS"Z"'
            )
        else to_varchar(
            dateadd(day, -mod(abs(hash(seq4() + 1001)), 1095), current_timestamp()),
            'YYYY-MM-DD HH24:MI:SS'
        )
    end as signed_up_at,
    (1885 + mod(abs(hash(seq4() + 2001)), 123))::varchar as birth_year,
    case mod(seq4(), 5)
        when 0 then 'Healing'
        when 1 then 'DIVINATION'
        when 2 then 'alchemy'
        when 3 then 'Charms'
        else 'Transfiguration'
    end as favored_discipline
from table(generator(rowcount => $customer_count));


-- ----------------------------------------------------------------------------
-- raw_guild_memberships
-- ~65% of customers have a current membership. One third of those get a
-- historical SCD2 row, producing realistic membership history.
-- ----------------------------------------------------------------------------
create or replace table raw_guild_memberships as
with current_memberships as (
    select
        seq4() + 1 as membership_num,
        seq4() + 1 as customer_num
    from table(generator(rowcount => floor($customer_count * 0.65)))
),

current_rows as (
    select
        membership_num,
        customer_num,
        'MEM-' || lpad(membership_num::varchar, 8, '0') as membership_id,
        'WIZ-' || lpad(customer_num::varchar, 8, '0') as customer_id,
        'GLD-' || lpad((1 + mod(abs(hash(customer_num + 3001)), 12))::varchar, 2, '0') as guild_id,
        case mod(customer_num, 3)
            when 0 then 'apprentice'
            when 1 then 'Adept'
            else 'ARCHMAGE'
        end as tier,
        to_varchar(
            dateadd(day, -mod(abs(hash(customer_num + 4001)), 900), current_date()),
            'YYYY-MM-DD'
        ) as valid_from,
        null::varchar as valid_to
    from current_memberships
),

historical_rows as (
    select
        'MEM-' || lpad((membership_num + $customer_count)::varchar, 8, '0') as membership_id,
        customer_id,
        guild_id,
        'apprentice' as tier,
        to_varchar(
            dateadd(day, -mod(abs(hash(membership_num + 5001)), 1300), current_date()),
            'YYYY-MM-DD'
        ) as valid_from,
        to_varchar(
            dateadd(day, -mod(abs(hash(membership_num + 5001)), 900), current_date()),
            'YYYY-MM-DD'
        ) as valid_to
    from current_rows
    where mod(membership_num, 3) = 0
)

select
    membership_id,
    customer_id,
    guild_id,
    tier,
    valid_from,
    valid_to
from current_rows

union all

select
    membership_id,
    customer_id,
    guild_id,
    tier,
    valid_from,
    valid_to
from historical_rows;


-- ----------------------------------------------------------------------------
-- raw_orders
-- One row per order. Dates are distributed across the past three years.
-- Orders use customers and shops from the shared source layer.
-- ----------------------------------------------------------------------------

create or replace table raw_orders as
with order_base as (
    select
        seq4() + 1 as order_num,
        1 + mod(abs(hash(seq4() + 6001)), $customer_count) as customer_num,
        1 + mod(abs(hash(seq4() + 7001)), 15) as shop_num,
        dateadd(
            second,
            mod(abs(hash(seq4() + 8001)), 86400),
            dateadd(day, -mod(abs(hash(seq4() + 9001)), 1095), current_date())
        ) as ordered_ts
    from table(generator(rowcount => $order_count))
)

select
    'ORD-' || lpad(order_num::varchar, 9, '0') as order_id,
    'WIZ-' || lpad(customer_num::varchar, 8, '0') as customer_id,
    'SHP-' || lpad(shop_num::varchar, 2, '0') as shop_id,
    case
        when mod(order_num, 2) = 0
            then to_varchar(ordered_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        else to_varchar(ordered_ts, 'YYYY-MM-DD HH24:MI:SS')
    end as ordered_at,
    case mod(order_num, 20)
        when 0 then 'returned'
        when 1 then 'cancelled'
        when 2 then 'placed'
        else 'completed'
    end as status,
    case mod(order_num, 3)
        when 0 then 'in_store'
        when 1 then 'courier_owl'
        else 'marketplace'
    end as channel,
    case
        when mod(order_num, 10) = 0
            then (50 + mod(abs(hash(order_num + 10001)), 350))::varchar
        else '0'
    end as discount_copper,
    $batch_ingested_at as ingested_at
from order_base;

-- ----------------------------------------------------------------------------
-- raw_order_items
-- 2-4 order lines per order; average 3.2, producing roughly 12M rows at the
-- default scale. potion_sku is deterministically assigned from the 120-item
-- potion catalog.
-- ----------------------------------------------------------------------------

create or replace table raw_order_items as
with orders as (
    select
        seq4() + 1 as order_num,
        'ORD-' || lpad((seq4() + 1)::varchar, 9, '0') as order_id,
        case
            when mod(seq4(), 5) = 0 then 2
            when mod(seq4(), 5) in (1, 2) then 3
            else 4
        end as line_count
    from table(generator(rowcount => $order_count))
),

line_numbers as (
    select seq4() + 1 as line_num
    from table(generator(rowcount => 4))
),

order_lines as (
    select
        orders.order_num,
        orders.order_id,
        line_numbers.line_num
    from orders
    cross join line_numbers
    where line_numbers.line_num <= orders.line_count
)

select
    'ITM-' || lpad(((order_num - 1) * 4 + line_num)::varchar, 10, '0') as order_item_id,
    order_id,
    'POT-' || lpad((1 + mod(abs(hash(order_num * 11 + line_num)), 120))::varchar, 4, '0') as potion_sku,
    (1 + mod(abs(hash(order_num * 13 + line_num)), 5))::varchar as quantity,
    (
        350
        + mod(abs(hash(order_num * 17 + line_num)), 1800)
        + mod(order_num, 365)
    )::varchar as unit_price_copper,
    $batch_ingested_at as ingested_at
from order_lines;


-- ----------------------------------------------------------------------------
-- raw_payments
-- One successful payment per order plus:
--   - second success on ~8% of orders
--   - failed attempt on ~5% of orders
--   - refund on ~3% of orders
--
-- This is deliberate: the fanout between order items and payment attempts
-- produces a materially expensive bad-state join at workshop scale.
-- ----------------------------------------------------------------------------

create or replace table raw_payments as
with order_payment_flags as (
    select
        seq4() + 1 as order_num,
        'ORD-' || lpad((seq4() + 1)::varchar, 9, '0') as order_id,
        dateadd(
            minute,
            mod(abs(hash(seq4() + 11001)), 240),
            dateadd(day, -mod(abs(hash(seq4() + 9001)), 1095), current_timestamp())
        ) as paid_ts,
        mod(seq4(), 25) = 0 as has_split_payment,
        mod(seq4(), 20) = 0 as has_failed_attempt,
        mod(seq4(), 33) = 0 as has_refund
    from table(generator(rowcount => $order_count))
),

payment_rows as (
    select order_num, order_id, paid_ts, 1 as attempt_num, 'success' as payment_status
    from order_payment_flags

    union all

    select order_num, order_id, dateadd(minute, -2, paid_ts), 2, 'success'
    from order_payment_flags
    where has_split_payment

    union all

    select order_num, order_id, dateadd(minute, -5, paid_ts), 3, 'failed'
    from order_payment_flags
    where has_failed_attempt

    union all

    select order_num, order_id, dateadd(day, 1, paid_ts), 4, 'refunded'
    from order_payment_flags
    where has_refund
)

select
    'PAY-' || lpad(((order_num - 1) * 4 + attempt_num)::varchar, 10, '0') as payment_id,
    order_id,
    case mod(order_num + attempt_num, 4)
        when 0 then 'coin'
        when 1 then 'guild_credit'
        when 2 then 'crystal_transfer'
        else 'barter'
    end as method,
    (500 + mod(abs(hash(order_num * 29 + attempt_num)), 7500))::varchar as amount_copper,
    payment_status as status,
    case
        when mod(order_num + attempt_num, 2) = 0
            then to_varchar(paid_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        else to_varchar(paid_ts, 'YYYY-MM-DD HH24:MI:SS')
    end as paid_at,
    $batch_ingested_at as ingested_at
from payment_rows;

-- ----------------------------------------------------------------------------
-- raw_brew_events
-- One row per brew batch. This is not a workshop optimization module, but the
-- full dbt project requires it. It scales independently from commercial facts.
-- ----------------------------------------------------------------------------

create or replace table raw_brew_events as
with brew_base as (
    select
        seq4() + 1 as brew_num,
        1 + mod(abs(hash(seq4() + 12001)), 120) as potion_num,
        1 + mod(abs(hash(seq4() + 13001)), 15) as shop_num,
        dateadd(
            second,
            mod(abs(hash(seq4() + 14001)), 86400),
            dateadd(day, -mod(abs(hash(seq4() + 15001)), 1095), current_date())
        ) as brewed_ts
    from table(generator(rowcount => $brew_event_count))
)

select
    'BRW-' || lpad(brew_num::varchar, 10, '0') as brew_id,
    'POT-' || lpad(potion_num::varchar, 4, '0') as potion_sku,
    'SHP-' || lpad(shop_num::varchar, 2, '0') as shop_id,
    'CDR-' || lpad((1 + mod(abs(hash(brew_num + 16001)), 20))::varchar, 2, '0') as cauldron_id,
    case
        when mod(brew_num, 2) = 0
            then to_varchar(brewed_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        else to_varchar(brewed_ts, 'YYYY-MM-DD HH24:MI:SS')
    end as brewed_at,
    (25 + mod(abs(hash(brew_num + 17001)), 226))::varchar as batch_size,
    case
        when mod(brew_num, 100) = 0 then null
        else (20 + mod(abs(hash(brew_num + 18001)), 221))::varchar
    end as brew_duration_minutes,
    case
        when mod(brew_num, 14) = 0 then 'FAIL'
        else 'pass'
    end as quality_check,
    'Brewer ' || (1 + mod(abs(hash(brew_num + 19001)), 250))::varchar as brewer_name
from brew_base;
