# frozen_string_literal: true

module DatabaseHelpers
  def test_schema
    ENV["POSTGRES_SCHEMA"] || "pger"
  end

  def connection_url
    "postgres://jamesbond:jamesbond@localhost:5432/postgres"
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

    PgEasyReplicate::Query.run(
      connection_url: connection_url,
      query: new_dummy_table_sql,
    )

    PgEasyReplicate::Query.run(
      connection_url: connection_url,
      query: "SET search_path TO #{test_schema};",
    )
  end

  def self.populate_env_vars
    ENV[
      "SOURCE_DB_URL"
    ] = "postgres://jamesbond:jamesbond@localhost:5432/postgres"
    ENV[
      "TARGET_DB_URL"
    ] = "postgres://jamesbond:jamesbond@localhost:5432/postgres"
  end
end
