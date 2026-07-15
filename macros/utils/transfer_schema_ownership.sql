{#
    ============================================================================
    Macro: transfer_object_ownership
    ----------------------------------------------------------------------------
    Purpose:
      Runs at the end of a dbt invocation (via on-run-end) and transfers
      Snowflake ownership of everything the run touched -- schemas, tables,
      and views -- to a designated governance/owner role.

      This is the mechanism that lets the dbt service role safely hold
      CREATE SCHEMA / CREATE TABLE / CREATE VIEW privileges: dbt can create
      whatever a build requires (so deploy and CI jobs never fail on missing
      objects), and every object it creates immediately becomes owned by the
      role your governance model actually wants controlling long-term access
      -- not the dbt service role.

      Because Snowflake ownership carries implicit full access, transferring
      it away also removes dbt's ability to write to that object on the next
      run (e.g. an incremental merge). Step 3 below grants back exactly the
      operating privileges dbt needs, so the pattern is self-sustaining across
      runs rather than a one-way handoff that breaks incrementals.

    Prerequisites (confirm before enabling):
      - The dbt role must either already have `target_role` granted to it,
        or hold MANAGE GRANTS on the account. Snowflake will reject the
        ownership transfer otherwise.
      - `COPY CURRENT GRANTS` preserves any grants that existed before the
        transfer (e.g. to BI tools, analyst roles) so they survive the hop.

    Usage (dbt_project.yml):
      on-run-end:
        - "{{ transfer_object_ownership(target_role=env_var('DBT_OWNERSHIP_TARGET_ROLE')) }}"

      `target_role` is read from an environment variable rather than a dbt
      var: dbt Cloud only supports per-developer overrides for environment
      variables (each developer can set their own value under their personal
      Development credentials), not for project vars. If this ever needs to
      differ by data domain (e.g. a separate governance role for a more
      restricted dataset) rather than by environment, an env var set per
      dbt Cloud environment still covers that.

      `dbt_role` is intentionally NOT passed above -- see the parameter note
      below.

      Ownership transfer runs the same way in every context, including
      Studio IDE dev sessions -- a developer's own dev schema is governed
      by `target_role` just like CI/staging/prod output is. dbt Cloud's
      built-in `DBT_CLOUD_INVOCATION_CONTEXT` variable (values: dev, staging,
      prod, ci -- set automatically by dbt Cloud, not configurable) is only
      used to label log output, not to skip anything, so a dev-session
      transfer is distinguishable from a CI/deploy one in run logs.

    Recommended rollout:
      Test in a sandbox project/schema first, and dry-run against a
      non-production environment before adding to a real deploy job --
      this macro issues GRANT OWNERSHIP statements, which are not
      reversible without another explicit grant.
    ============================================================================
#}

{% macro transfer_object_ownership(target_role, dbt_role=none) %}

  {% if execute %}

    {#
      Ownership transfer applies uniformly across every context -- dev,
      staging, prod, and ci -- so a developer's own dev schema is governed
      the same way as a deploy job's output. Falls back to
      'local' when unset (e.g. dbt Core CLI outside dbt Cloud entirely).
    #}
    {% set invocation_context = env_var('DBT_CLOUD_INVOCATION_CONTEXT', 'local') %}

    {#
      If dbt_role isn't explicitly passed, resolve it to whatever role is
      actually running this invocation. This is deliberate: Snowflake already
      knows the operating role for the current session -- a developer's
      personal role in Studio IDE dev sessions, the CI/deploy service role
      elsewhere -- so asking it directly removes the need to maintain any
      role mapping per environment or per developer. New team members just
      work, and their dev schemas get the same governance handoff as every
      other context.
    #}
    {% if dbt_role is none %}
      {% set current_role_query %}
        select current_role() as role
      {% endset %}
      {% set dbt_role = run_query(current_role_query).columns[0].values()[0] %}
    {% endif %}

    {# ---------------------------------------------------------------------
       Step 1: transfer ownership of every schema touched by this run,
       then immediately grant back what dbt needs to keep building in it.
       --------------------------------------------------------------------- #}
    {% for db_schema in database_schemas %}
      {% set database_name = db_schema[0] %}
      {% set schema_name = db_schema[1] %}
      {% set qualified_schema = database_name ~ "." ~ schema_name %}

      {% set schema_ownership_sql %}
        grant ownership on schema {{ qualified_schema }}
        to role {{ target_role }}
        copy current grants
      {% endset %}

      {% set schema_regrant_sql %}
        grant usage, create table, create view
        on schema {{ qualified_schema }}
        to role {{ dbt_role }}
      {% endset %}

      {% do log("[" ~ invocation_context ~ "] Transferring ownership of schema " ~ qualified_schema ~ " to " ~ target_role ~ " (dbt_role: " ~ dbt_role ~ ")", info=true) %}
      {% do run_query(schema_ownership_sql) %}
      {% do run_query(schema_regrant_sql) %}

    {% endfor %}

    {# ---------------------------------------------------------------------
       Step 2: transfer ownership of every model/seed/snapshot built this run.
       Ephemeral models never hit the warehouse, so they're skipped, and
       only successful builds are touched.
       --------------------------------------------------------------------- #}
    {% for result in results %}

      {% set node = result.node %}

      {% if result.status in ['success', 'pass'] and node.resource_type in ['model', 'seed', 'snapshot'] %}

        {% set materialization = node.config.materialized %}

        {% if materialization != 'ephemeral' %}

          {% set object_type = 'view' if materialization == 'view' else 'table' %}
          {% set qualified_object = node.database ~ "." ~ node.schema ~ "." ~ node.alias %}

          {% set relation_ownership_sql %}
            grant ownership on {{ object_type }} {{ qualified_object }}
            to role {{ target_role }}
            copy current grants
          {% endset %}

          {# ------------------------------------------------------------
             Step 3: grant back the privileges dbt needs to keep operating
             on this specific object (critical for incremental models,
             which write to the same table on every subsequent run).
             ------------------------------------------------------------ #}
          {% if object_type == 'table' %}
            {% set relation_regrant_sql %}
              grant select, insert, update, delete, truncate
              on table {{ qualified_object }}
              to role {{ dbt_role }}
            {% endset %}
          {% else %}
            {% set relation_regrant_sql %}
              grant select
              on view {{ qualified_object }}
              to role {{ dbt_role }}
            {% endset %}
          {% endif %}

          {% do log("[" ~ invocation_context ~ "] Transferring ownership of " ~ object_type ~ " " ~ qualified_object ~ " to " ~ target_role ~ " (dbt_role: " ~ dbt_role ~ ")", info=true) %}
          {% do run_query(relation_ownership_sql) %}
          {% do run_query(relation_regrant_sql) %}

        {% endif %}
      {% endif %}

    {% endfor %}

    {# ---------------------------------------------------------------------
       Step 4 (optional but recommended): future grants at the schema level,
       so objects created outside a tracked dbt run (seeds loaded manually,
       ad hoc DDL, etc.) still grant dbt continued access without needing
       this hook to have run against them first.
       --------------------------------------------------------------------- #}
    {% for db_schema in database_schemas %}
      {% set database_name = db_schema[0] %}
      {% set schema_name = db_schema[1] %}
      {% set qualified_schema = database_name ~ "." ~ schema_name %}

      {% set future_tables_sql %}
        grant select, insert, update, delete, truncate
        on future tables in schema {{ qualified_schema }}
        to role {{ dbt_role }}
      {% endset %}

      {% set future_views_sql %}
        grant select
        on future views in schema {{ qualified_schema }}
        to role {{ dbt_role }}
      {% endset %}

      {% do run_query(future_tables_sql) %}
      {% do run_query(future_views_sql) %}

    {% endfor %}

  {% endif %}

{% endmacro %}