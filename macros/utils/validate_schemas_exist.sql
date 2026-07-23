{#
    ============================================================================
    Macro: validate_schemas_exist
    ----------------------------------------------------------------------------
    Purpose:
      Pre-flight check for environments where dbt's role cannot create schemas
      (no CREATE SCHEMA privilege). Run via `dbt run-operation` as a standalone
      job chained ahead of the real deploy/merge job (on-success trigger), so
      promotion is blocked with a clear, complete error *before* a deploy job
      dies partway through the DAG on a missing-schema permissions error.

      Because `run-operation` still fully parses the project graph before
      executing anything, `graph.nodes` already contains every model, seed,
      and snapshot's fully resolved database/schema (including anything
      determined by a custom generate_schema_name macro) with nothing actually
      built. That resolved list is exactly the set of schemas this environment
      needs to already have.

      Uses `adapter.check_schema_exists()`, which only requires USAGE on the
      database to read -- a far lower privilege than creating one -- so this
      should work under the same lockdown that's causing the promotion
      failures in the first place, with no new grants needed.

    Scope / known gaps:
      - Checks schemas for models, seeds, and snapshots (non-ephemeral).
      - Does NOT check source schemas -- those are expected to pre-exist
        independent of dbt and aren't something dbt ever creates.
      - Does NOT check schemas used only by `store_failures` on tests, since
        those aren't resolvable from graph.nodes the same way. If they rely
        on store_failures heavily, that's worth a follow-up pass.

    Usage:
      dbt run-operation validate_schemas_exist

      Exits non-zero (via raise_compiler_error) if anything is missing, which
      is what makes the job fail, which is what should block the on-success
      trigger from firing the downstream deploy/merge job.

    Optional: to scope the check to a specific selection rather than the
    whole project, pass a --select-style filter into the args and swap the
    `graph.nodes.values()` loop below for `graph.nodes.values() | selectattr(...)`
    or an equivalent node-selection helper -- not included here to keep this
    version simple and whole-project by default.
    ============================================================================
#}

{% macro validate_schemas_exist() %}

  {% if execute %}

    {#
      Collect every unique (database, schema) pair this project will need to
      write into. Ephemeral models are skipped since they never materialize
      as a warehouse object and therefore never need a schema to exist.
    #}
    {% set schema_pairs = [] %}

    {% for node in graph.nodes.values() %}
      {% if node.resource_type in ['model', 'seed', 'snapshot'] and node.config.materialized != 'ephemeral' %}
        {% set pair = (node.database, node.schema) %}
        {% if pair not in schema_pairs %}
          {% do schema_pairs.append(pair) %}
        {% endif %}
      {% endif %}
    {% endfor %}

    {% do log("Checking " ~ schema_pairs | length ~ " unique schema(s) required by this project...", info=true) %}

    {% set missing_schemas = [] %}

    {% for pair in schema_pairs %}
      {% set database_name = pair[0] %}
      {% set schema_name = pair[1] %}
      {% set qualified_schema = database_name ~ "." ~ schema_name %}

      {% set schema_exists = adapter.check_schema_exists(database_name, schema_name) %}

      {% if schema_exists %}
        {% do log("  [OK]      " ~ qualified_schema, info=true) %}
      {% else %}
        {% do log("  [MISSING] " ~ qualified_schema, info=true) %}
        {% do missing_schemas.append(qualified_schema) %}
      {% endif %}

    {% endfor %}

    {% if missing_schemas | length > 0 %}

      {% set error_message %}
{{ missing_schemas | length }} schema(s) required by this project do not exist in this environment and must be created before code can be promoted:

{% for schema in missing_schemas %}  - {{ schema }}
{% endfor %}
Create these schemas (or have whoever administers Snowflake create them) before re-running promotion.
      {% endset %}

      {% do exceptions.raise_compiler_error(error_message) %}

    {% else %}

      {% do log("All " ~ schema_pairs | length ~ " required schema(s) exist. Safe to proceed with promotion.", info=true) %}

    {% endif %}

  {% endif %}

{% endmacro %}