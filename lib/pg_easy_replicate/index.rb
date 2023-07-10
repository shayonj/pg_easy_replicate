# frozen_string_literal: true

module PgEasyReplicate
  class Index
    extend Helper

    class << self
      def drop(conn_string:, tables:, schema:)
        indexes
      end

      def recreate(conn_string:, indexes:, tables:, schema:)
      end
    end
  end
end
