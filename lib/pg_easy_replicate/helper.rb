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
  end
end
