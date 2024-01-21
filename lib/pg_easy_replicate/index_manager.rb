# frozen_string_literal: true

module PgEasyReplicate
  module IndexManager
    extend Helper

    def self.drop_indices(
      source_conn_string:,
      target_conn_string:,
      tables:,
      schema:
    )
      logger.info("Dropping indices from target database")

      fetch_indices(
        conn_string: source_conn_string,
        tables: tables,
        schema: schema,
      ).each do |index|
        drop_sql = "DROP INDEX CONCURRENTLY #{schema}.#{index[:index_name]};"

        Query.run(
          query: drop_sql,
          connection_url: target_conn_string,
          schema: schema,
          transaction: false,
        )
      end
    end

    def self.recreate_indices(
      source_conn_string:,
      target_conn_string:,
      tables:,
      schema:
    )
      logger.info("Recreating indices on target database")

      indices =
        fetch_indices(
          conn_string: source_conn_string,
          tables: tables,
          schema: schema,
        )
      indices.each do |index|
        create_sql =
          "#{index[:index_definition].gsub("CREATE INDEX", "CREATE INDEX CONCURRENTLY IF NOT EXISTS")};"

        Query.run(
          query: create_sql,
          connection_url: target_conn_string,
          schema: schema,
          transaction: false,
        )
      end
    end

    def self.fetch_indices(conn_string:, tables:, schema:)
      return [] if tables.empty?
      table_list = tables.map { |table| "'#{table}'" }.join(",")

      sql = <<-SQL
        SELECT
            t.relname AS table_name,
            i.relname AS index_name,
            pg_get_indexdef(i.oid) AS index_definition
        FROM
            pg_class t,
            pg_class i,
            pg_index ix,
            pg_namespace n
        WHERE
            t.oid = ix.indrelid
            AND i.oid = ix.indexrelid
            AND n.oid = t.relnamespace
            AND t.relkind = 'r'  -- only find indexes of tables
            AND ix.indisprimary = FALSE  -- exclude primary keys
            AND ix.indisunique = FALSE  -- exclude unique indexes
            AND n.nspname = '#{schema}'
            AND t.relname IN (#{table_list})
        ORDER BY
            t.relname,
            i.relname;
      SQL
      Query.run(query: sql, connection_url: conn_string, schema: schema)
    end

    def self.wait_for_replication_completion(group_name:)
      loop do
        break if Stats.all_tables_replicating?(group_name)
        sleep(5)
      end
    end
  end
end
