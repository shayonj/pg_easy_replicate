# frozen_string_literal: true

module DatabaseHelpers
  def test_schema
    ENV["POSTGRES_SCHEMA"] || "pger_test"
  end

  # We are use url encoded password below.
  # Original password is james-bond123@7!'3aaR
  def connection_url(user = "james-bond")
    "postgres://#{user}:james-bond123%407%21%273aaR@localhost:5432/postgres-db"
  end

  def target_connection_url(user = "james-bond")
    "postgres://#{user}:james-bond123%407%21%273aaR@localhost:5433/postgres-db"
  end

  def docker_compose_target_connection_url(user = "james-bond")
    "postgres://#{user}:james-bond123%407%21%273aaR@target_db/postgres-db"
  end

  def docker_compose_source_connection_url(user = "james-bond")
    return connection_url(user) if ENV["GITHUB_WORKFLOW"] # if running in CI/github actions
    "postgres://#{user}:james-bond123%407%21%273aaR@source_db/postgres-db"
  end

  def setup_tables(user = "james-bond", setup_target_db: true)
    setup(connection_url(user), user)
    setup(target_connection_url(user), user) if setup_target_db
  end

  def setup_roles
    [connection_url, target_connection_url].each do |url|
      PgEasyReplicate::Query.run(
        query:
          "drop role if exists #{PG::Connection.quote_ident("james-bond_sup")}; create user #{PG::Connection.quote_ident("james-bond_sup")} with login superuser password 'james-bond123@7!''3aaR';",
        connection_url: url,
        user: "james-bond",
      )

      PgEasyReplicate::Query.run(
        query:
          "drop role if exists no_sup; create user no_sup with login password 'james-bond123@7!''3aaR';",
        connection_url: url,
        user: "james-bond",
      )

      # setup role
      PgEasyReplicate::Query.run(
        query:
          "drop role if exists #{PG::Connection.quote_ident("james-bond_super_role")}; create role #{PG::Connection.quote_ident("james-bond_super_role")} with createdb createrole replication;",
        connection_url: url,
        user: "james-bond",
      )

      # setup user with role
      sql = <<~SQL
        drop role if exists #{PG::Connection.quote_ident("james-bond_role_regular")};
        create role #{PG::Connection.quote_ident("james-bond_role_regular")} WITH createrole createdb replication LOGIN PASSWORD 'james-bond123@7!''3aaR'; grant #{PG::Connection.quote_ident("james-bond_super_role")} to #{PG::Connection.quote_ident("james-bond_role_regular")};
        grant all privileges on database #{PG::Connection.quote_ident("postgres-db")} TO #{PG::Connection.quote_ident("james-bond_role_regular")};
      SQL
      PgEasyReplicate::Query.run(
        query: sql,
        connection_url: url,
        user: "james-bond",
      )
    end
  end

  def cleanup_roles
    %w[
      james-bond_sup
      no_sup
      james-bond_role_regular
      james-bond_super_role
    ].each do |role|
      if role == "james-bond_role_regular"
        PgEasyReplicate::Query.run(
          query:
            "revoke all privileges on database #{PG::Connection.quote_ident("postgres-db")} from #{PG::Connection.quote_ident("james-bond_role_regular")};",
          connection_url: connection_url,
          user: "james-bond",
        )

        PgEasyReplicate::Query.run(
          query:
            "revoke all privileges on database #{PG::Connection.quote_ident("postgres-db")} from #{PG::Connection.quote_ident("james-bond_role_regular")};",
          connection_url: target_connection_url,
          user: "james-bond",
        )
      end

      PgEasyReplicate::Query.run(
        query: "drop role if exists #{PG::Connection.quote_ident(role)};",
        connection_url: connection_url,
        user: "james-bond",
      )

      PgEasyReplicate::Query.run(
        query: "drop role if exists #{PG::Connection.quote_ident(role)};",
        connection_url: target_connection_url,
        user: "james-bond",
      )
    end
  end

  def setup(connection_url, user = "james-bond")
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

    unless conn.table_exists?("sellers")
      conn.create_table("sellers") do
        primary_key(:id)
        column(:name, String, unique: true)
        column(:last_login, Time)
        index(:id)
        index(:last_login)
      end
    end

    unless conn.table_exists?("items")
      conn.create_table("items") do
        primary_key(:id)
        column(:name, String)
        column(:last_purchase_at, Time)
        foreign_key(:seller_id, :sellers, on_delete: :cascade)
        index(:seller_id)
        index(:id)
      end
    end

    unless conn.table_exists?("spatial_ref_sys")
      conn.create_table("spatial_ref_sys") do
        primary_key(:id)
        column(:name, String)
        column(:last_purchase_at, Time)
        foreign_key(:seller_id, :sellers, on_delete: :cascade)
        index(:seller_id)
        index(:id)
      end
    end
  ensure
    conn&.disconnect
  end

  def teardown_tables
    PgEasyReplicate::Query.run(
      query: "DROP SCHEMA IF EXISTS #{test_schema} CASCADE;",
      connection_url: connection_url,
      user: "james-bond",
    )

    PgEasyReplicate::Query.run(
      query: "DROP SCHEMA IF EXISTS #{test_schema} CASCADE;",
      connection_url: target_connection_url,
      user: "james-bond",
    )
  end

  def get_schema
    PgEasyReplicate::Query.run(
      query:
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '#{PgEasyReplicate.internal_schema_name}';",
      connection_url: connection_url,
      schema: PgEasyReplicate.internal_schema_name,
      user: "james-bond",
    )
  end

  def groups_table_exists?
    PgEasyReplicate::Query.run(
      query:
        "SELECT table_name FROM information_schema.tables WHERE  table_name = 'groups'",
      connection_url: connection_url,
      schema: PgEasyReplicate.internal_schema_name,
      user: "james-bond",
    )
  end

  def user_permissions(connection_url:, group_name:)
    PgEasyReplicate::Query.run(
      query:
        "select rolcreatedb, rolcreaterole, rolcanlogin, rolsuper from pg_authid where rolname = 'pger_su_h1a4fb';",
      connection_url: connection_url,
      user: "james-bond",
    )
  end

  def pg_subscriptions(connection_url:)
    PgEasyReplicate::Query.run(
      query:
        "select subname, subpublications, subslotname, subenabled from pg_subscription;",
      connection_url: connection_url,
      user: "james-bond",
    )
  end

  def pg_publication_tables(connection_url:)
    PgEasyReplicate::Query.run(
      query: "select pubname, schemaname, tablename from pg_publication_tables ORDER BY tablename;",
      connection_url: connection_url,
      user: "james-bond",
    )
  end

  def pg_publications(connection_url:)
    PgEasyReplicate::Query.run(
      query: "select pubname from pg_catalog.pg_publication",
      connection_url: connection_url,
      user: "james-bond",
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
    ] = "postgres://james-bond:james-bond123%407%21%273aaR@localhost:5432/postgres-db"
    ENV[
      "TARGET_DB_URL"
    ] = "postgres://james-bond:james-bond123%407%21%273aaR@localhost:5433/postgres-db"
  end

  def table_exists?(*args)
    if args.size == 1
      table_name = args.first
      schema = PgEasyReplicate::DDLAudit.send(:internal_schema_name)
      conn_url = connection_url
    elsif args.size == 3
      conn_url, schema, table_name = args
    else
      raise ArgumentError,
            "Wrong number of arguments (given #{args.size}, expected 1 or 3)"
    end

    PgEasyReplicate::Query.run(
      query:
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = '#{schema}' AND table_name = '#{table_name}') AS exists",
      connection_url: conn_url,
      schema: schema,
      user: "james-bond",
    ).first[
      :exists
    ]
  end

  def column_exists?(conn_url, schema, table, column)
    PgEasyReplicate::Query.run(
      query:
        "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = '#{schema}' AND table_name = '#{table}' AND column_name = '#{column}') AS exists",
      connection_url: conn_url,
      schema: schema,
      user: "james-bond",
    ).first[
      :exists
    ]
  end

  def function_exists?(function_name, conn_url = connection_url)
    PgEasyReplicate::Query.run(
      query:
        "SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = '#{function_name}') AS exists",
      connection_url: conn_url,
      user: "james-bond",
    ).first[
      :exists
    ]
  end

  def event_triggers_exist?(group_name, conn_url = nil)
    conn_url ||= connection_url # Use the default connection_url if not provided
    raise "No connection URL provided" if conn_url.nil?

    PgEasyReplicate::Query.run(
      query:
        "SELECT COUNT(*) FROM pg_event_trigger WHERE evtname IN ('pger_ddl_trigger_#{group_name}', 'pger_drop_trigger_#{group_name}', 'pger_table_rewrite_trigger_#{group_name}')",
      connection_url: conn_url,
      schema: PgEasyReplicate::DDLAudit.send(:internal_schema_name),
    ).first[
      :count
    ] == 3
  end

  def execute_ddl(query, conn_url = connection_url)
    PgEasyReplicate::Query.run(
      query: query,
      connection_url: conn_url,
      schema: test_schema,
      user: "james-bond",
    )
  end

  def ddl_audit_table_exists?(conn_url = nil, table_name = nil)
    schema = PgEasyReplicate::DDLAudit.send(:internal_schema_name)
    conn_url = connection_url if conn_url.nil? || conn_url.is_a?(Symbol)
    table_name ||= "pger_ddl_audits"

    PgEasyReplicate::Query.run(
      query:
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = '#{schema}' AND table_name = '#{table_name}') AS exists",
      connection_url: conn_url,
      schema: schema,
      user: "james-bond",
    ).first[
      :exists
    ]
  end

  def ddl_trigger_function_exists?(conn_url = connection_url)
    function_exists?("pger_ddl_trigger", conn_url)
  end

  def table_exists_in_schema?(conn_url, schema, table_name)
    PgEasyReplicate::Query.run(
      query:
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = '#{schema}' AND table_name = '#{table_name}') AS exists",
      connection_url: conn_url,
      schema: schema,
      user: "james-bond",
    ).first[
      :exists
    ]
  end
end
