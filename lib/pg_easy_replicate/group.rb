# frozen_string_literal: true

module PgEasyReplicate
  class Group
    extend Helper
    class << self
      def setup
        sql = <<~SQL
          CREATE TABLE groups (
            id serial PRIMARY KEY,
            source_db_connstring TEXT  UNIQUE NOT NULL,
            target_db_connstring TEXT  UNIQUE NOT NULL,
            encryption_key VARCHAR NOT NULL,
            name TEXT  UNIQUE NOT NULL,
            table_names TEXT,
            schema_name TEXT,
            created_at TIMESTAMP default current_timestamp NOT NULL,
            started_at TIMESTAMP,
            completed_at TIMESTAMP
          );
        SQL

        PgEasyReplicate::Query.run(
          query: sql,
          connection_url: source_db_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      end

      def drop
        sql = <<~SQL
          DROP TABLE IF EXISTS groups;
        SQL
        PgEasyReplicate::Query.run(
          query: sql,
          connection_url: source_db_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      end

      def create(options)
        # Insert row
      end

      def find(group_name)
        sql = <<~SQL
          select * from groups where group_name = #{group_name}
        SQL
        PgEasyReplicate::Query.run(query: sql, connection_url: source_db_url)
      end

      def delete(options)
        # assert prelimnary checks
        # assert subscription publication is setup
      end
    end
  end
end
