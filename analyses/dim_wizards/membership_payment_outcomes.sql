with base as (
    select
        customer_id,
        payment_status,
        paid_date,
        amount_gold
    from {{ ref('fct_payments') }}
    where paid_date between '2026-04-01' and '2026-06-30'
),

final as (
    select
        wizards.membership_tier,
        wizards.is_guild_member,
        base.payment_status,
        count(*) as payment_attempt_count,
        sum(base.amount_gold) as total_payment_amount_gold
    from base
    left join {{ ref('dim_wizards') }} as wizards
        on base.customer_id = wizards.customer_id
    group by
        wizards.membership_tier,
        wizards.is_guild_member,
        base.payment_status
)

select * from final
order by is_guild_member desc, membership_tier, payment_status
