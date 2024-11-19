# frozen_string_literal: true

module PgEasyReplicate
  module Helper
    def source_db_url
      ENV.fetch("SOURCE_DB_URL", nil)
    end

    def secondary_source_db_url
      ENV.fetch("SECONDARY_SOURCE_DB_URL", nil)
    end

    def target_db_url
      ENV.fetch("TARGET_DB_URL", nil)
    end

    def logger
      PgEasyReplicate.logger
    end

    def internal_schema_name
      "pger"
    end

    def internal_user_name
      "pger_su_h1a4fb"
    end

    def publication_name(group_name)
      "pger_publication_#{underscore(group_name)}"
    end

    def subscription_name(group_name)
      "pger_subscription_#{underscore(group_name)}"
    end

    def underscore(str)
      str
        .gsub("::", "/")
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr("-", "_")
        .downcase
    end

    def quote_ident(sql_ident)
      PG::Connection.quote_ident(sql_ident)
    end

    def test_env?
      ENV.fetch("RACK_ENV", nil) == "test"
    end

    def connection_info(conn_string)
      PG::Connection
        .conninfo_parse(conn_string)
        .each_with_object({}) do |obj, hash|
          hash[obj[:keyword].to_sym] = obj[:val]
        end
        .compact
    end

    def db_user(url)
      connection_info(url)[:user]
    end

    def db_name(url)
      connection_info(url)[:dbname]
    end

    def abort_with(msg)
      raise(msg) if test_env?
      abort(msg)
    end

    def determine_tables(conn_string:, list: "", exclude_list: "", schema: nil)
      schema ||= "public"

      tables = convert_to_array(list)
      exclude_tables = convert_to_array(exclude_list)
      validate_table_lists(tables, exclude_tables, schema)

      if tables.empty?
        all_tables = list_all_tables(schema: schema, conn_string: conn_string)
        all_tables - (exclude_tables + %w[spatial_ref_sys])
      else
        tables
      end
    end

    def list_all_tables(schema:, conn_string:)
      Query
        .run(
          query:
            "SELECT c.relname::information_schema.sql_identifier AS table_name
             FROM pg_namespace n
               JOIN pg_class c ON n.oid = c.relnamespace
             WHERE c.relkind = 'r'
               AND c.relpersistence = 'p'
               AND n.nspname::information_schema.sql_identifier = '#{schema}'
             ORDER BY table_name",
          connection_url: conn_string,
          user: db_user(conn_string),
        )
        .map(&:values)
        .flatten
    end

    def convert_to_array(input)
      input.is_a?(Array) ? input : input&.split(",") || []
    end

    def validate_table_lists(tables, exclude_tables, schema_name)
      table_list = convert_to_array(tables)
      exclude_table_list = convert_to_array(exclude_tables)

      if !table_list.empty? && !exclude_table_list.empty?
        abort_with(
          "Options --tables(-t) and --exclude-tables(-e) cannot be used together.",
        )
      elsif !table_list.empty?
        if table_list.size > 0 && (schema_name.nil? || schema_name == "")
          abort_with("Schema name is required if tables are passed")
        end
      elsif exclude_table_list.size > 0 &&
            (schema_name.nil? || schema_name == "")
        abort_with("Schema name is required if exclude tables are passed")
      end
    end

    def restore_connections_on_source_db
      logger.info("Restoring connections")

      alter_sql =
        "ALTER USER #{quote_ident(db_user(source_db_url))} set default_transaction_read_only = false"
      Query.run(query: alter_sql, connection_url: source_db_url)
    end
  end
end
