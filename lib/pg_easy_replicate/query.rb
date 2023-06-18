# frozen_string_literal: true

module PgEasyReplicate
  class Query
    extend Helper

    class << self
      def run(
        query:,
        connection_url:,
        schema: nil,
        user: nil,
        transaction: true
      )
        conn = connect(connection_url, user: user)
        if transaction
          r =
            conn.transaction do
              conn.run("SET search_path to #{schema}") if schema
              conn.run("SET statement_timeout to '5s'")
              conn.fetch(query).to_a
            end
        else
          conn.run("SET search_path to #{schema}") if schema
          conn.run("SET statement_timeout to '5s'")
          r = conn.fetch(query).to_a
        end
        conn.disconnect
        r
      ensure
        conn&.fetch("RESET statement_timeout")
        conn&.disconnect
      end

      def connect(connection_url, schema = nil, user: nil)
        c =
          Sequel.connect(
            connection_url,
            user: user || db_user(connection_url),
            logger: ENV.fetch("DEBUG", nil) ? logger : nil,
            search_path: schema,
          )
        logger.debug("Connection established")
        c
      end
    end
  end
end
