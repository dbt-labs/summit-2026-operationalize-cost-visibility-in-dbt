{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set env_type = env_var('DBT_CLOUD_ENVIRONMENT_TYPE', 'DEV') | upper -%}
    {%- set invocation_context = env_var('DBT_CLOUD_INVOCATION_CONTEXT', '') | upper -%}
    {%- set default_schema = target.schema -%}

    {# Keep dbt's default schema generation in dev and CI #}
    {%- if env_type == 'DEV' or invocation_context == 'CI' -%}
        {%- if custom_schema_name is none -%}
            {{ default_schema }}
        {%- else -%}
            {{ default_schema }}_{{ custom_schema_name | trim }}
        {%- endif -%}
    {# In staging/prod deployment environments, use the configured custom schema directly #}
    {%- elif custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
