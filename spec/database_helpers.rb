# frozen_string_literal: true

module DatabaseHelpers
  def test_schema
    ENV["POSTGRES_SCHEMA"] || "pger_test"
  end

  def connection_url
    "postgres://jamesbond:jamesbond@localhost:5432/postgres"
  end

  def target_connection_url
    "postgres://jamesbond:jamesbond@localhost:5433/postgres"
  end

  def new_dummy_table_sql
    <<~SQL
      CREATE SCHEMA IF NOT EXISTS #{test_schema};

      CREATE TABLE IF NOT EXISTS #{test_schema}.sellers (
        id serial PRIMARY KEY,
        name VARCHAR ( 50 ) UNIQUE NOT NULL,
        "createdOn" TIMESTAMP NOT NULL,
        last_login TIMESTAMP
      );
    SQL
  end

  def setup_tables
    PgEasyReplicate::Query.run(
      query: "DROP SCHEMA IF EXISTS #{test_schema} CASCADE;",
      connection_url: connection_url,
    )

    conn = PgEasyReplicate::Query.connect(connection_url)
    conn.run(
      "CREATE SCHEMA IF NOT EXISTS #{test_schema}; SET search_path TO #{test_schema};",
    )
    return if conn.table_exists?("sellers")
    conn.create_table("sellers") do
      primary_key(:id)
      column(:name, String)
      column(:last_login, Time)
    end
  end

  def get_schema
    PgEasyReplicate::Query.run(
      query:
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '#{PgEasyReplicate.internal_schema_name}';",
      connection_url: connection_url,
      schema: PgEasyReplicate.internal_schema_name,
    )
  end

  def groups_table_exists?
    PgEasyReplicate::Query.run(
      query:
        "SELECT table_name FROM information_schema.tables WHERE  table_name = 'groups'",
      connection_url: connection_url,
      schema: PgEasyReplicate.internal_schema_name,
    )
  end

  def user_permissions(connection_url)
    PgEasyReplicate::Query.run(
      query:
        "select rolcreatedb, rolcreaterole, rolcanlogin, rolsuper from pg_authid where rolname = 'pger_replication_user';",
      connection_url: connection_url,
    )
  end

  def self.populate_env_vars
    ENV[
      "SOURCE_DB_URL"
    ] = "postgres://jamesbond:jamesbond@localhost:5432/postgres"
    ENV[
      "TARGET_DB_URL"
    ] = "postgres://jamesbond:jamesbond@localhost:5433/postgres"
  end
end
