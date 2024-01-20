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
        drop_sql = "DROP INDEX CONCURRENTLY #{index[:index_name]};"

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
      return [] if tables.split(",").empty?
      table_list = tables.split(",").map { |table| "'#{table}'" }.join(",")

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
            AND n.nspname = '#{schema}'
            AND t.relname IN (#{table_list})
        ORDER BY
            t.relname,
            i.relname;
      SQL
      Query.run(query: sql, connection_url: conn_string, schema: schema)
    end

    def self.drop_constraints(
      source_conn_string:,
      target_conn_string:,
      tables:,
      schema:
    )
      logger.info("Dropping constraints from target database")

      # Fetch constraints from the source database
      constraints =
        fetch_constraints(
          conn_string: source_conn_string,
          tables: tables,
          schema: schema,
        )

      constraints.each do |constraint|
        drop_constraint_sql =
          "ALTER TABLE #{constraint[:table_name]} DROP CONSTRAINT IF EXISTS #{constraint[:constraint_name]};"
        Query.run(
          query: drop_constraint_sql,
          connection_url: target_conn_string,
          schema: schema,
          transaction: false,
        )
      end
    end

    def self.fetch_constraints(conn_string:, tables:, schema:)
      return [] if tables.split(",").empty?
      table_list = tables.split(",").map { |table| "'#{table}'" }.join(",")

      sql = <<-SQL
        SELECT
            conrelid::regclass AS table_name,
            conname AS constraint_name,
            pg_get_constraintdef(oid) AS constraint_definition
        FROM
            pg_constraint
        WHERE
            contype IN ('p', 'u') -- primary key, unique
            AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = '#{schema}')
            AND conrelid::regclass::text IN (#{table_list})
      SQL
      Query.run(query: sql, connection_url: conn_string, schema: schema)
    end

    # Recreate constraints, validating them if they were valid on the source
    def self.recreate_constraints(
      source_conn_string:,
      target_conn_string:,
      tables:,
      schema:
    )
      logger.info("Recreating constraints on target database")

      constraints =
        fetch_constraints(
          conn_string: source_conn_string,
          tables: tables,
          schema: schema,
        )

      constraints.each do |constraint|
        not_valid_exists =
          constraint[:constraint_definition].include?("NOT VALID")

        constraint_definition =
          (
            if not_valid_exists
              constraint[:constraint_definition]
            else
              "#{constraint[:constraint_definition]} NOT VALID"
            end
          )

        add_constraint_sql =
          "ALTER TABLE #{constraint[:table_name]} ADD CONSTRAINT #{constraint[:constraint_name]} #{constraint_definition};"
        Query.run(
          query: add_constraint_sql,
          connection_url: target_conn_string,
          schema: schema,
          transaction: false,
        )

        next if constraint[:constraint_definition].include?("NOT VALID")
        validate_constraint_sql =
          "ALTER TABLE #{constraint[:table_name]} VALIDATE CONSTRAINT #{constraint[:constraint_name]};"
        Query.run(
          query: validate_constraint_sql,
          connection_url: target_conn_string,
          schema: schema,
          transaction: false,
        )
      end
    end

    def self.recreate_indices_and_constraints(
      source_conn_string:,
      target_conn_string:,
      tables:,
      schema:
    )
      logger.info("Recreating indices and constraints on target database")

      recreate_indices(
        source_conn_string: source_conn_string,
        target_conn_string: target_conn_string,
        tables: tables,
        schema: schema,
      )

      recreate_constraints(
        source_conn_string: source_conn_string,
        target_conn_string: target_conn_string,
        tables: tables,
        schema: schema,
      )
    end

    def self.wait_for_replication_completion(group_name:)
      loop do
        break if Stats.all_tables_replicating?(group_name)
        sleep(5)
      end
    end
  end
end
