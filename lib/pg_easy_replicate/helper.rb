# frozen_string_literal: true

module PgEasyReplicate
  module Helper
    def source_db_url
      ENV.fetch("SOURCE_DB_URL", nil)
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

    def test_env?
      ENV.fetch("RACK_ENV", nil) == "test"
    end

    def connection_info(conn_string)
      conn_info = PG::Connection.conninfo_parse(conn_string)
      {
        user: conn_info.find { |k| k[:keyword] == "user" }[:val],
        dbname: conn_info.find { |k| k[:keyword] == "dbname" }[:val],
        host: conn_info.find { |k| k[:keyword] == "host" }[:val],
        port: conn_info.find { |k| k[:keyword] == "port" }[:val],
        options: conn_info.find { |k| k[:keyword] == "options" }[:val],
      }
    end

    def db_user(url)
      connection_info(url)[:user]
    end

    def abort_with(msg)
      raise(msg) if test_env?
      abort(msg)
    end
  end
end
