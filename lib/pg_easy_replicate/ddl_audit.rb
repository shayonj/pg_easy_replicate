# frozen_string_literal: true

require "pg_query"

module PgEasyReplicate
  class DDLAudit
    extend Helper

    class << self
      def setup(group_name)
        conn = connect_to_internal_schema
        return if conn.table_exists?(table_name)

        begin
          conn.create_table(table_name) do
            primary_key(:id)
            String(:group_name, null: false)
            String(:event_type, null: false)
            String(:object_type)
            String(:object_identity)
            String(:ddl_command, text: true)
            DateTime(:created_at, default: Sequel::CURRENT_TIMESTAMP)
          end

          create_trigger_function(conn, group_name)
          create_event_triggers(conn, group_name)
        rescue => e
          abort_with("Failed to set up DDL audit: #{e.message}")
        ensure
          conn&.disconnect
        end
      end

      def create(
        group_name,
        event_type,
        object_type,
        object_identity,
        ddl_command
      )
        conn = connect_to_internal_schema
        begin
          conn[table_name].insert(
            group_name: group_name,
            event_type: event_type,
            object_type: object_type,
            object_identity: object_identity,
            ddl_command: ddl_command,
            created_at: Time.now.utc,
          )
        rescue => e
          abort_with("Adding DDL audit entry failed: #{e.message}")
        ensure
          conn&.disconnect
        end
      end

      def list_changes(group_name, limit: 100)
        conn = connect_to_internal_schema
        begin
          conn[table_name]
            .where(group_name: group_name)
            .order(Sequel.desc(:id))
            .limit(limit)
            .all
        rescue => e
          abort_with("Listing DDL changes failed: #{e.message}")
        ensure
          conn&.disconnect
        end
      end

      def apply_change(source_conn_string, target_conn_string, group_name, id)
        ddl_queries = fetch_ddl_query(source_conn_string, group_name, id: id)
        apply_ddl_changes(target_conn_string, ddl_queries)
      end

      def apply_all_changes(source_conn_string, target_conn_string, group_name)
        ddl_queries = fetch_ddl_query(source_conn_string, group_name)
        apply_ddl_changes(target_conn_string, ddl_queries)
      end

      def drop(group_name)
        conn = connect_to_internal_schema
        begin
          drop_event_triggers(conn, group_name)
          drop_trigger_function(conn, group_name)
          conn[table_name].where(group_name: group_name).delete
        rescue => e
          abort_with("Dropping DDL audit failed: #{e.message}")
        ensure
          conn&.disconnect
        end
      end

      private

      def table_name
        :pger_ddl_audits
      end

      def connect_to_internal_schema(conn_string = nil)
        Query.connect(
          connection_url: conn_string || source_db_url,
          schema: internal_schema_name,
        )
      end

      def create_trigger_function(conn, group_name)
        group = PgEasyReplicate::Group.find(group_name)
        tables = group[:table_names].split(",").map(&:strip)
        schema_name = group[:schema_name]
        sanitized_group_name = sanitize_identifier(group_name)

        full_table_names = tables.map { |table| "#{schema_name}.#{table}" }
        table_pattern = full_table_names.join("|")

        conn.run(<<~SQL)
          CREATE OR REPLACE FUNCTION #{internal_schema_name}.pger_ddl_trigger_#{sanitized_group_name}() RETURNS event_trigger AS $$
          DECLARE
            obj record;
            ddl_command text;
            affected_table text;
          BEGIN
            SELECT current_query() INTO ddl_command;

            IF TG_EVENT = 'ddl_command_end' THEN
              FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
              LOOP
                IF obj.object_identity ~ '^(#{table_pattern})' THEN
                  INSERT INTO #{internal_schema_name}.#{table_name} (group_name, event_type, object_type, object_identity, ddl_command)
                  VALUES ('#{group_name}', TG_EVENT, obj.object_type, obj.object_identity, ddl_command);
                ELSIF obj.object_type = 'index' THEN
                  SELECT (regexp_match(ddl_command, 'ON\\s+(\\S+)'))[1] INTO affected_table;
                  IF affected_table IN ('#{full_table_names.join("','")}') THEN
                    INSERT INTO #{internal_schema_name}.#{table_name} (group_name, event_type, object_type, object_identity, ddl_command)
                    VALUES ('#{group_name}', TG_EVENT, obj.object_type, obj.object_identity, ddl_command);
                  END IF;
                END IF;
              END LOOP;
            ELSIF TG_EVENT = 'sql_drop' THEN
              FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
              LOOP
                IF (obj.object_identity = ANY(ARRAY['#{full_table_names.join("','")}']) OR
                    obj.object_identity ~ ('^' || '#{schema_name}' || '\\.(.*?)_.*$'))
                THEN
                  INSERT INTO #{internal_schema_name}.#{table_name} (group_name, event_type, object_type, object_identity, ddl_command)
                  VALUES ('#{group_name}', TG_EVENT, obj.object_type, obj.object_identity, ddl_command);
                END IF;
              END LOOP;
            ELSIF TG_EVENT = 'table_rewrite' THEN
              FOR obj IN SELECT * FROM pg_event_trigger_table_rewrite_oid()
              LOOP
                SELECT c.relname, n.nspname INTO affected_table
                FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.oid = obj.oid;

                IF affected_table IN ('#{full_table_names.join("','")}') THEN
                  INSERT INTO #{internal_schema_name}.#{table_name} (group_name, event_type, object_type, object_identity, ddl_command)
                  VALUES ('#{group_name}', TG_EVENT, 'table', affected_table, 'table_rewrite');
                END IF;
              END LOOP;
            END IF;
          END;
          $$ LANGUAGE plpgsql;
        SQL
      rescue => e
        abort_with("Creating DDL trigger function failed: #{e.message}")
      end

      def create_event_triggers(conn, group_name)
        sanitized_group_name = sanitize_identifier(group_name)

        pg_version = conn.fetch("SHOW server_version_num").first[:server_version_num].to_i
        execute_keyword = pg_version >= 110000 ? "FUNCTION" : "PROCEDURE"

        conn.run(<<~SQL)
          DROP EVENT TRIGGER IF EXISTS pger_ddl_trigger_#{sanitized_group_name};
          CREATE EVENT TRIGGER pger_ddl_trigger_#{sanitized_group_name} ON ddl_command_end
          EXECUTE #{execute_keyword} #{internal_schema_name}.pger_ddl_trigger_#{sanitized_group_name}();

          DROP EVENT TRIGGER IF EXISTS pger_drop_trigger_#{sanitized_group_name};
          CREATE EVENT TRIGGER pger_drop_trigger_#{sanitized_group_name} ON sql_drop
          EXECUTE #{execute_keyword} #{internal_schema_name}.pger_ddl_trigger_#{sanitized_group_name}();

          DROP EVENT TRIGGER IF EXISTS pger_table_rewrite_trigger_#{sanitized_group_name};
          CREATE EVENT TRIGGER pger_table_rewrite_trigger_#{sanitized_group_name} ON table_rewrite
          EXECUTE #{execute_keyword} #{internal_schema_name}.pger_ddl_trigger_#{sanitized_group_name}();
        SQL
      rescue => e
        abort_with("Creating event triggers failed: #{e.message}")
      end

      def drop_event_triggers(conn, group_name)
        sanitized_group_name = sanitize_identifier(group_name)
        conn.run(<<~SQL)
          DROP EVENT TRIGGER IF EXISTS pger_ddl_trigger_#{sanitized_group_name};
          DROP EVENT TRIGGER IF EXISTS pger_drop_trigger_#{sanitized_group_name};
          DROP EVENT TRIGGER IF EXISTS pger_table_rewrite_trigger_#{sanitized_group_name};
        SQL
      rescue => e
        abort_with("Dropping event triggers failed: #{e.message}")
      end

      def drop_trigger_function(conn, group_name)
        sanitized_group_name = sanitize_identifier(group_name)
        conn.run(
          "DROP FUNCTION IF EXISTS #{internal_schema_name}.pger_ddl_trigger_#{sanitized_group_name}();",
        )
      rescue => e
        abort_with("Dropping trigger function failed: #{e.message}")
      end

      def self.extract_table_info(sql)
        parsed = PgQuery.parse(sql)
        stmt = parsed.tree.stmts.first.stmt

        case stmt
        when PgQuery::CreateStmt, PgQuery::IndexStmt, PgQuery::AlterTableStmt
          schema_name = stmt.relation.schemaname || "public"
          table_name = stmt.relation.relname
          "#{schema_name}.#{table_name}"
        end
      rescue PgQuery::ParseError
        nil
      end

      def sanitize_identifier(identifier)
        identifier.gsub(/[^a-zA-Z0-9_]/, "_")
      end

      def fetch_ddl_query(source_conn_string, group_name, id: nil)
        source_conn = connect_to_internal_schema(source_conn_string)
        begin
          query = source_conn[table_name].where(group_name: group_name)
          query = query.where(id: id) if id
          result = query.order(:id).select_map(:ddl_command)
          result.uniq
        rescue => e
          abort_with("Fetching DDL queries failed: #{e.message}")
        ensure
          source_conn&.disconnect
        end
      end

      def apply_ddl_changes(target_conn_string, ddl_queries)
        target_conn = Query.connect(connection_url: target_conn_string)
        begin
          ddl_queries.each do |query|
            target_conn.run(query)
          rescue => e
            abort_with(
              "Error executing DDL command: #{query}. Error: #{e.message}",
            )
          end
        rescue => e
          abort_with("Applying DDL changes failed: #{e.message}")
        ensure
          target_conn&.disconnect
        end
      end
    end
  end
end
