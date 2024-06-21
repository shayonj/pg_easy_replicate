# frozen_string_literal: true

require "json"
require "ougai"
require "pg"
require "sequel"
require "open3"
require "English"

require "pg_easy_replicate/helper"
require "pg_easy_replicate/version"
require "pg_easy_replicate/query"
require "pg_easy_replicate/index_manager"
require "pg_easy_replicate/orchestrate"
require "pg_easy_replicate/stats"
require "pg_easy_replicate/group"
require "pg_easy_replicate/cli"

Sequel.default_timezone = :utc
module PgEasyReplicate
  SCHEMA_FILE_LOCATION = "/tmp/pger_schema.sql"

  class Error < StandardError
  end

  extend Helper

  class << self
    def config(
      special_user_role: nil,
      copy_schema: false,
      tables: "",
      exclude_tables: "",
      schema_name: nil
    )
      abort_with("SOURCE_DB_URL is missing") if source_db_url.nil?
      abort_with("TARGET_DB_URL is missing") if target_db_url.nil?
      
      if !tables.empty? && !exclude_tables.empty?
        abort_with("Options --tables(-t) and --exclude-tables(-e) cannot be used together.")
      end

      system("which pg_dump")
      pg_dump_exists = $CHILD_STATUS.success?

      @config ||=
        begin
          q =
            "select name, setting from pg_settings where name in  ('max_wal_senders', 'max_worker_processes', 'wal_level',  'max_replication_slots', 'max_logical_replication_workers');"

          {
            source_db_is_super_user:
              is_super_user?(source_db_url, special_user_role),
            target_db_is_super_user:
              is_super_user?(target_db_url, special_user_role),
            source_db:
              Query.run(
                query: q,
                connection_url: source_db_url,
                user: db_user(source_db_url),
              ),
            target_db:
              Query.run(
                query: q,
                connection_url: target_db_url,
                user: db_user(target_db_url),
              ),
            pg_dump_exists: pg_dump_exists,
            tables_have_replica_identity:
              tables_have_replica_identity?(
                conn_string: source_db_url,
                tables: tables,
                exclude_tables: exclude_tables,
                schema_name: schema_name,
              ),
          }
        rescue => e
          abort_with("Unable to check config: #{e.message}")
        end
    end

    def assert_config(
      special_user_role: nil,
      copy_schema: false,
      tables: "",
      exclude_tables: "",
      schema_name: nil
    )
      config_hash =
        config(
          special_user_role: special_user_role,
          copy_schema: copy_schema,
          tables: tables,
          exclude_tables: exclude_tables,
          schema_name: schema_name,
        )

      if copy_schema && !config_hash.dig(:pg_dump_exists)
        abort_with("pg_dump must exist if copy_schema (-c) is passed")
      end

      unless assert_wal_level_logical(config_hash.dig(:source_db))
        abort_with("WAL_LEVEL should be LOGICAL on source DB")
      end

      unless assert_wal_level_logical(config_hash.dig(:target_db))
        abort_with("WAL_LEVEL should be LOGICAL on target DB")
      end

      unless config_hash.dig(:source_db_is_super_user)
        abort_with("User on source database does not have super user privilege")
      end

      validate_table_lists(tables, exclude_tables, schema_name)

      unless config_hash.dig(:tables_have_replica_identity)
        abort_with(
          "Ensure all tables involved in logical replication have an appropriate replica identity set. This can be done using:
        1. Default (Primary Key): `ALTER TABLE table_name REPLICA IDENTITY DEFAULT;`
        2. Unique Index: `ALTER TABLE table_name REPLICA IDENTITY USING INDEX index_name;`
        3. Full (All Columns): `ALTER TABLE table_name REPLICA IDENTITY FULL;`",
        )
      end

      return if config_hash.dig(:target_db_is_super_user)
      abort_with("User on target database does not have super user privilege")
    end

    def bootstrap(options)
      logger.info("Setting up schema")
      setup_internal_schema

      if options[:copy_schema]
        logger.info("Setting up schema on target database")
        copy_schema(
          source_conn_string: source_db_url,
          target_conn_string: target_db_url,
        )
      end

      logger.info("Setting up replication user on source database")
      create_user(
        conn_string: source_db_url,
        special_user_role: options[:special_user_role],
        grant_permissions_on_schema: true,
      )

      logger.info("Setting up replication user on target database")
      create_user(
        conn_string: target_db_url,
        special_user_role: options[:special_user_role],
      )

      logger.info("Setting up groups tables")
      Group.setup
    rescue => e
      abort_with("Unable to bootstrap: #{e.message}")
    end

    def cleanup(options)
      logger.info("Dropping groups table")
      Group.drop

      if options[:everything]
        logger.info("Dropping schema")
        drop_internal_schema
      end

      if options[:everything] || options[:sync]
        Orchestrate.drop_publication(
          group_name: options[:group_name],
          conn_string: source_db_url,
        )

        Orchestrate.drop_subscription(
          group_name: options[:group_name],
          target_conn_string: target_db_url,
        )
      end

      if options[:everything]
        # Drop users at last
        logger.info("Dropping replication user on source database")
        drop_user(conn_string: source_db_url)

        logger.info("Dropping replication user on target database")
        drop_user(conn_string: target_db_url)
      end
    rescue => e
      abort_with("Unable to cleanup: #{e.message}")
    end

    def drop_internal_schema
      Query.run(
        query:
          "DROP SCHEMA IF EXISTS #{quote_ident(internal_schema_name)} CASCADE",
        connection_url: source_db_url,
        schema: internal_schema_name,
        user: db_user(source_db_url),
      )
    rescue => e
      raise "Unable to drop schema: #{e.message}"
    end

    def setup_internal_schema
      sql = <<~SQL
        create schema if not exists #{quote_ident(internal_schema_name)};
        grant usage on schema #{quote_ident(internal_schema_name)} to #{quote_ident(db_user(source_db_url))};
        grant create on schema #{quote_ident(internal_schema_name)} to #{quote_ident(db_user(source_db_url))};
      SQL

      Query.run(
        query: sql,
        connection_url: source_db_url,
        schema: internal_schema_name,
        user: db_user(source_db_url),
      )
    rescue => e
      raise "Unable to setup schema: #{e.message}"
    end

    def logger
      @logger ||=
        begin
          logger = Ougai::Logger.new($stdout)
          logger.level =
            ENV["DEBUG"] ? Ougai::Logger::TRACE : Ougai::Logger::INFO
          logger.with_fields = { version: PgEasyReplicate::VERSION }
          logger
        end
    end

    def copy_schema(source_conn_string:, target_conn_string:)
      export_schema(conn_string: source_conn_string)
      import_schema(conn_string: target_conn_string)
    end

    def export_schema(conn_string:)
      logger.info("Exporting schema to #{SCHEMA_FILE_LOCATION}")
      _, stderr, status =
        Open3.capture3(
          "pg_dump",
          conn_string,
          "-f",
          SCHEMA_FILE_LOCATION,
          "--schema-only",
        )

      success = status.success?
      raise stderr unless success
    rescue => e
      raise "Unable to export schema: #{e.message}"
    end

    def import_schema(conn_string:)
      logger.info("Importing schema from #{SCHEMA_FILE_LOCATION}")

      _, stderr, status =
        Open3.capture3("psql", "-f", SCHEMA_FILE_LOCATION, conn_string)

      success = status.success?
      raise stderr unless success
    rescue => e
      raise "Unable to import schema: #{e.message}"
    end

    def assert_wal_level_logical(db_config)
      db_config&.find do |r|
        r.dig(:name) == "wal_level" && r.dig(:setting) == "logical"
      end
    end

    def is_super_user?(url, special_user_role = nil)
      if special_user_role
        sql = <<~SQL
          SELECT r.rolname AS username,
            r1.rolname AS "role"
          FROM pg_catalog.pg_roles r
          LEFT JOIN pg_catalog.pg_auth_members m ON (m.member = r.oid)
          LEFT JOIN pg_roles r1 ON (m.roleid=r1.oid)
          WHERE r.rolname = '#{db_user(url)}'
          ORDER BY 1;
        SQL

        r = Query.run(query: sql, connection_url: url, user: db_user(url))
        # If special_user_role is passed just ensure the url in conn_string has been granted
        # the special_user_role
        r.any? { |q| q[:role] == special_user_role }
      else
        r =
          Query.run(
            query:
              "SELECT rolname, rolsuper FROM pg_roles where rolname = '#{db_user(url)}';",
            connection_url: url,
            user: db_user(url),
          )
        r.any? { |q| q[:rolsuper] }
      end
    rescue => e
      raise "Unable to check superuser conditions: #{e.message}"
    end

    def create_user(
      conn_string:,
      special_user_role: nil,
      grant_permissions_on_schema: false
    )
      password = connection_info(conn_string)[:password].gsub("'") { "''" }

      drop_user(conn_string: conn_string)

      sql = <<~SQL
        create role #{quote_ident(internal_user_name)} with password '#{password}' login createdb createrole;
        grant all privileges on database #{quote_ident(db_name(conn_string))} TO #{quote_ident(internal_user_name)};
      SQL

      Query.run(
        query: sql,
        connection_url: conn_string,
        user: db_user(conn_string),
        transaction: false,
      )

      sql =
        if special_user_role
          "grant #{quote_ident(special_user_role)} to #{quote_ident(internal_user_name)};"
        else
          "alter user #{quote_ident(internal_user_name)} with superuser;"
        end

      Query.run(
        query: sql,
        connection_url: conn_string,
        user: db_user(conn_string),
        transaction: false,
      )

      return unless grant_permissions_on_schema
      Query.run(
        query:
          "grant all on schema #{quote_ident(internal_schema_name)} to #{quote_ident(internal_user_name)}",
        connection_url: conn_string,
        user: db_user(conn_string),
        transaction: false,
      )
    rescue => e
      raise "Unable to create user: #{e.message}"
    end

    def drop_user(conn_string:, user: internal_user_name)
      return unless user_exists?(conn_string: conn_string, user: user)

      sql = <<~SQL
       revoke all privileges on database #{quote_ident(db_name(conn_string))} from #{quote_ident(user)};
      SQL

      Query.run(
        query: sql,
        connection_url: conn_string,
        user: db_user(conn_string),
      )

      sql = <<~SQL
        drop role if exists #{quote_ident(user)};
      SQL

      Query.run(
        query: sql,
        connection_url: conn_string,
        user: db_user(conn_string),
      )
    rescue => e
      raise "Unable to drop user: #{e.message}"
    end

    def user_exists?(conn_string:, user: internal_user_name)
      sql = <<~SQL
        SELECT r.rolname AS username,
          r1.rolname AS "role"
        FROM pg_catalog.pg_roles r
        LEFT JOIN pg_catalog.pg_auth_members m ON (m.member = r.oid)
        LEFT JOIN pg_roles r1 ON (m.roleid=r1.oid)
        WHERE r.rolname = '#{user}'
        ORDER BY 1;
      SQL

      Query
        .run(
          query: sql,
          connection_url: conn_string,
          user: db_user(conn_string),
        )
        .any? { |q| q[:username] == user }
    end

    def tables_have_replica_identity?(
      conn_string:,
      tables: "",
      exclude_tables: "",
      schema_name: nil
    )
      schema_name ||= "public"

      table_list =
        determine_tables(
          schema: schema_name,
          conn_string: source_db_url,
          list: tables,
          exclude_list: exclude_tables,
        )
      return false if table_list.empty?

      formatted_table_list = table_list.map { |table| "'#{table}'" }.join(", ")

      sql = <<~SQL
        SELECT t.relname AS table_name,
              CASE
                WHEN t.relreplident = 'd' THEN 'default'
                WHEN t.relreplident = 'n' THEN 'nothing'
                WHEN t.relreplident = 'i' THEN 'index'
                WHEN t.relreplident = 'f' THEN 'full'
              END AS replica_identity
        FROM pg_class t
        JOIN pg_namespace ns ON t.relnamespace = ns.oid
        WHERE ns.nspname = '#{schema_name}'
          AND t.relkind = 'r'
          AND t.relname IN (#{formatted_table_list})
      SQL

      results =
        Query.run(
          query: sql,
          connection_url: conn_string,
          user: db_user(conn_string),
        )

      results.all? { |r| r[:replica_identity] != "nothing" }
    end
  end
end
