# frozen_string_literal: true

module PgEasyReplicate
  class Group
    extend Helper
    class << self
      def setup
        sql = <<~SQL
          CREATE TABLE groups (
            id serial PRIMARY KEY,
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
        sql = <<~SQL
          insert into groups (name, table_names, schema_name)
          values ($1, $2, $3);
        SQL
        values = [options[:name], options[:table_names], options[:schema_name]]

        PgEasyReplicate::Query.run_prepared(
          statement: sql,
          values: values,
          connection_url: source_db_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      rescue => e
        abort("Adding group entry failed: #{e.message}")
      end

      def update(group_name:, started_at: nil, completed_at: nil)
        sql = <<~SQL
          UPDATE groups
          SET started_at = $1,
          completed_at = $2
          WHERE name= $3
          RETURNING *
        SQL
        values = [started_at&.utc, completed_at&.utc, group_name]

        PgEasyReplicate::Query.run_prepared(
          statement: sql,
          values: values,
          connection_url: source_db_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      rescue => e
        abort("Updating group entry failed: #{e.message}")
      end

      def find(group_name)
        sql = <<~SQL
          select * from groups where name = '#{group_name}' limit 1
        SQL

        PgEasyReplicate::Query.run(
          query: sql,
          connection_url: source_db_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      rescue => e
        abort("Finding group entry failed: #{e.message}")
      end

      def delete(group_name)
        sql = <<~SQL
          DELETE from groups where name = '#{group_name}'
        SQL

        PgEasyReplicate::Query.run(
          query: sql,
          connection_url: source_db_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      rescue => e
        abort("Deleting group entry failed: #{e.message}")
      end
    end
  end
end
