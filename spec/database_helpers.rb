# frozen_string_literal: true

module DatabaseHelpers
  def test_schema
    ENV["POSTGRES_SCHEMA"] || "pger_test"
  end

  # We are use url encoded password below.
  # Original password is jamesbond123@7!'3aaR
  def connection_url(user = "jamesbond")
    "postgres://#{user}:jamesbond123%407%21%273aaR@localhost:5432/postgres"
  end

  def target_connection_url(user = "jamesbond")
    "postgres://#{user}:jamesbond123%407%21%273aaR@localhost:5433/postgres"
  end

  def docker_compose_target_connection_url(user = "jamesbond")
    "postgres://#{user}:jamesbond123%407%21%273aaR@target_db/postgres"
  end

  def docker_compose_source_connection_url(user = "jamesbond")
    return connection_url(user) if ENV["GITHUB_WORKFLOW"] # if running in CI/github actions
    "postgres://#{user}:jamesbond123%407%21%273aaR@source_db/postgres"
  end

  def setup_tables(user = "jamesbond")
    setup(connection_url(user), user)
    setup(target_connection_url(user), user)
  end

  def setup_roles
    [connection_url, target_connection_url].each do |url|
      PgEasyReplicate::Query.run(
        query:
          "drop role if exists jamesbond_sup; create user jamesbond_sup with login superuser password 'jamesbond123@7!''3aaR';",
        connection_url: url,
        user: "jamesbond",
      )

      PgEasyReplicate::Query.run(
        query:
          "drop role if exists no_sup; create user no_sup with login password 'jamesbond123@7!''3aaR';",
        connection_url: url,
        user: "jamesbond",
      )

      # setup role
      PgEasyReplicate::Query.run(
        query:
          "drop role if exists jamesbond_super_role; create role jamesbond_super_role with createdb createrole replication;",
        connection_url: url,
        user: "jamesbond",
      )

      # setup user with role
      sql = <<~SQL
        drop role if exists jamesbond_role_regular;
        create role jamesbond_role_regular WITH createrole createdb replication LOGIN PASSWORD 'jamesbond123@7!''3aaR'; grant jamesbond_super_role to jamesbond_role_regular;
        grant all privileges on database postgres TO jamesbond_role_regular;
      SQL
      PgEasyReplicate::Query.run(
        query: sql,
        connection_url: url,
        user: "jamesbond",
      )
    end
  end

  def cleanup_roles
    %w[
      jamesbond_sup
      no_sup
      jamesbond_role_regular
      jamesbond_super_role
    ].each do |role|
      if role == "jamesbond_role_regular"
        PgEasyReplicate::Query.run(
          query:
            "revoke all privileges on database postgres from jamesbond_role_regular;",
          connection_url: connection_url,
          user: "jamesbond",
        )

        PgEasyReplicate::Query.run(
          query:
            "revoke all privileges on database postgres from jamesbond_role_regular;",
          connection_url: target_connection_url,
          user: "jamesbond",
        )
      end

      PgEasyReplicate::Query.run(
        query: "drop role if exists #{role};",
        connection_url: connection_url,
        user: "jamesbond",
      )

      PgEasyReplicate::Query.run(
        query: "drop role if exists #{role};",
        connection_url: target_connection_url,
        user: "jamesbond",
      )
    end
  end

  def setup(connection_url, user = "jamesbond")
    PgEasyReplicate::Query.run(
      query: "DROP SCHEMA IF EXISTS #{test_schema} CASCADE;",
      connection_url: connection_url,
      user: user,
    )

    conn =
      PgEasyReplicate::Query.connect(connection_url: connection_url, user: user)
    conn.run(
      "CREATE SCHEMA IF NOT EXISTS #{test_schema}; SET search_path TO #{test_schema};",
    )

    return if conn.table_exists?("sellers")
    conn.create_table("sellers") do
      primary_key(:id)
      column(:name, String)
      column(:last_login, Time)
    end

    return if conn.table_exists?("items")
    conn.create_table("items") do
      primary_key(:id)
      column(:name, String)
      column(:last_purchase_at, Time)
    end
  ensure
    conn&.disconnect
  end

  def teardown_tables
    PgEasyReplicate::Query.run(
      query: "DROP SCHEMA IF EXISTS #{test_schema} CASCADE;",
      connection_url: connection_url,
      user: "jamesbond",
    )

    PgEasyReplicate::Query.run(
      query: "DROP SCHEMA IF EXISTS #{test_schema} CASCADE;",
      connection_url: target_connection_url,
      user: "jamesbond",
    )
  end

  def get_schema
    PgEasyReplicate::Query.run(
      query:
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '#{PgEasyReplicate.internal_schema_name}';",
      connection_url: connection_url,
      schema: PgEasyReplicate.internal_schema_name,
      user: "jamesbond",
    )
  end

  def groups_table_exists?
    PgEasyReplicate::Query.run(
      query:
        "SELECT table_name FROM information_schema.tables WHERE  table_name = 'groups'",
      connection_url: connection_url,
      schema: PgEasyReplicate.internal_schema_name,
      user: "jamesbond",
    )
  end

  def user_permissions(connection_url:, group_name:)
    PgEasyReplicate::Query.run(
      query:
        "select rolcreatedb, rolcreaterole, rolcanlogin, rolsuper from pg_authid where rolname = 'pger_su_h1a4fb';",
      connection_url: connection_url,
      user: "jamesbond",
    )
  end

  def pg_subscriptions(connection_url:)
    PgEasyReplicate::Query.run(
      query:
        "select subname, subpublications, subslotname, subenabled from pg_subscription;",
      connection_url: connection_url,
      user: "jamesbond",
    )
  end

  def pg_publication_tables(connection_url:)
    PgEasyReplicate::Query.run(
      query: "select * from pg_publication_tables;",
      connection_url: connection_url,
      user: "jamesbond",
    )
  end

  def pg_publications(connection_url:)
    PgEasyReplicate::Query.run(
      query: "select pubname from pg_catalog.pg_publication",
      connection_url: connection_url,
      user: "jamesbond",
    )
  end

  def vacuum_stats(url:, schema:)
    PgEasyReplicate::Query.run(
      connection_url: url,
      schema: schema,
      query:
        "SELECT last_vacuum, last_analyze, relname FROM pg_stat_all_tables WHERE schemaname = '#{schema}'",
    )
  end

  def self.populate_env_vars
    ENV[
      "SOURCE_DB_URL"
    ] = "postgres://jamesbond:jamesbond123%407%21%273aaR@localhost:5432/postgres"
    ENV[
      "TARGET_DB_URL"
    ] = "postgres://jamesbond:jamesbond123%407%21%273aaR@localhost:5433/postgres"
  end
end
