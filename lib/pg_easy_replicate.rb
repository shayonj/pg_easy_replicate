# frozen_string_literal: true

require "json"
require "ougai"
require "lockbox"
require "pg"

require "pg_easy_replicate/helper"
require "pg_easy_replicate/version"
require "pg_easy_replicate/secure"
require "pg_easy_replicate/query"
require "pg_easy_replicate/cli"

module PgEasyReplicate
  class Error < StandardError
  end

  extend Helper

  class << self
    def config
      abort("SOURCE_DB_URL is missing") if source_db_url.nil?
      abort("TARGET_DB_URL is missing") if target_db_url.nil?
      @config ||=
        begin
          q =
            "select name, setting from pg_settings where name in  ('max_wal_senders', 'max_worker_processes', 'wal_level',  'max_replication_slots', 'max_logical_replication_workers');"

          {
            source_db_is_superuser: is_super_user?(source_db_url),
            target_db_is_superuser: is_super_user?(target_db_url),
            source_db:
              PgEasyReplicate::Query.run(
                query: q,
                connection_url: source_db_url,
              ),
            target_db:
              PgEasyReplicate::Query.run(
                query: q,
                connection_url: target_db_url,
              ),
          }
        rescue PG::ConnectionBad, PG::Error => e
          abort("Unable to connect: #{e.message}")
        end
    end

    def assert_config
      unless assert_wal_level_logical(config.dig(:source_db))
        abort("WAL_LEVEL should be LOGICAL on source DB")
      end

      unless assert_wal_level_logical(config.dig(:target_db))
        abort("WAL_LEVEL should be LOGICAL on target DB")
      end

      unless config.dig(:source_db_is_superuser)
        abort("User on source database should be a superuser")
      end

      return if config.dig(:target_db_is_superuser)
      abort("User on target database should be a superuser")
    end

    def bootstrap(options)
      assert_config
      # setup table to persist info for schema, group, table
      # setup association with source db, target db and group
      # setup replication user
    end

    def cleanup(options)
      # drop self created tables
      # drop publication and subscriptions from both DBs - if everything
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

    private

    def assert_wal_level_logical(db_config)
      db_config&.find do |r|
        r.dig("name") == "wal_level" && r.dig("setting") == "logical"
      end
    end

    def is_super_user?(db_url)
      PgEasyReplicate::Query.run(
        query:
          "select usesuper from pg_user where usename = '#{connection_info(db_url)[:user]}';",
        connection_url: db_url,
      ).first[
        "usesuper"
      ] == "t"
    end
  end
end
