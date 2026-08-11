{#-
    conform_region(column)

    raw_shops.region is the canonical spelling (five values). CRM
    raw_customers.home_region is inconsistently coded — abbreviations
    (NR), lowercase (northern reaches), and canonical all appear. This maps
    every known variant back to canonical so revenue-by-region joins line up.

    Unrecognized values pass through trimmed (never silently dropped) so a
    new variant shows up in the accepted_values test instead of vanishing.
-#}
{% macro conform_region(column) %}
    case lower(trim({{ column }}))
        when 'nr' then 'Northern Reaches'
        when 'northern reaches' then 'Northern Reaches'
        when 'ec' then 'Ember Coast'
        when 'ember coast' then 'Ember Coast'
        when 'ember_coast' then 'Ember Coast'
        when 'sw' then 'Silverwood'
        when 'silverwood' then 'Silverwood'
        when 'ml' then 'The Marshlands'
        when 'the marshlands' then 'The Marshlands'
        when 'cv' then 'Crystal Vale'
        when 'crystal vale' then 'Crystal Vale'
        else trim({{ column }})
    end
{% endmacro %}
