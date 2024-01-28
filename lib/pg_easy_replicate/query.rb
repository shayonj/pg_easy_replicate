# frozen_string_literal: true

module PgEasyReplicate
  class Query
    extend Helper

    class << self
      def run(
        query:,
        connection_url:,
        user: internal_user_name,
        schema: nil,
        transaction: true,
        using_vacuum_analyze: false
      )
        conn =
          connect(connection_url: connection_url, schema: schema, user: user)
        timeout ||= "5s"
        if transaction
          r =
            conn.transaction do
              conn.run("SET search_path to #{quote_ident(schema)}") if schema
              conn.run("SET statement_timeout to '#{timeout}'")
              conn.fetch(query).to_a
            end
        else
          conn.run("SET search_path to #{quote_ident(schema)}") if schema
          if using_vacuum_analyze
            conn.run("SET statement_timeout=0")
          else
            conn.run("SET statement_timeout to '5s'")
          end
          r = conn.fetch(query).to_a
        end
        conn.disconnect
        r
      ensure
        conn&.fetch("RESET statement_timeout")
        conn&.disconnect
      end

      def connect(connection_url:, user: internal_user_name, schema: nil)
        c =
          Sequel.connect(
            connection_url,
            user: user,
            logger: ENV.fetch("DEBUG", nil) ? logger : nil,
            search_path: schema,
          )
        logger.debug("Connection established")
        c
      end
    end
  end
end
