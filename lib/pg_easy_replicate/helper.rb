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

    def determine_tables(conn_string:, list: "", schema: nil)
      schema ||= "public"

      tables = list&.split(",") || []
      if tables.size > 0
        tables
      else
        list_all_tables(schema: schema, conn_string: conn_string) - %w[ spatial_ref_sys ]
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
  end
end
