# frozen_string_literal: true

module PgEasyReplicate
  class Query
    extend Helper

    class << self
      def run(query:, connection_url:, schema: nil)
        conn = connect(connection_url)
        conn.async_exec("SET search_path to #{schema}") if schema
        conn.async_exec("BEGIN;")
        if [PG::PQTRANS_INERROR, PG::PQTRANS_UNKNOWN].include?(
             conn.transaction_status,
           )
          conn.cancel
        end

        logger.debug("Running query", { query: query })
        conn.async_exec("SET statement_timeout to '5s'")

        result = conn.async_exec(query).to_a
      rescue Exception # rubocop:disable Lint/RescueException
        if conn
          conn.cancel if conn.transaction_status != PG::PQTRANS_IDLE
          conn.block
          logger.error(
            "Exception raised, rolling back query",
            { rollback: true, query: query },
          )
          conn.async_exec("ROLLBACK;")
          conn.async_exec("COMMIT;")
          conn.async_exec("RESET statement_timeout")
        end
        raise
      else
        conn.async_exec("COMMIT;")
        conn.async_exec("RESET statement_timeout")
        result
      end

      def connect(connection_url)
        c = PG.connect(connection_url)
        logger.debug("Connection established")
        c
      end
    end
  end
end
