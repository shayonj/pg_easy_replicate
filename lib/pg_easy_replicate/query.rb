# frozen_string_literal: true

module PgEasyReplicate
  class Query
    extend Helper

    class << self
      def run(query:, connection_url:, schema: nil)
        conn = connect(connection_url)
        conn.transaction do
          conn.run("SET search_path to #{schema}") if schema
          conn.run("SET statement_timeout to '5s'")
          conn.fetch(query).to_a
        end
      ensure
        conn&.fetch("RESET statement_timeout")
      end

      def connect(connection_url, schema = nil)
        c = Sequel.connect(connection_url, logger: logger, search_path: schema)
        logger.debug("Connection established")
        c
      end
    end
  end
end
