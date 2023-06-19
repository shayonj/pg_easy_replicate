# frozen_string_literal: true

module PgEasyReplicate
  class Orchestrate
    extend Helper

    class << self
      DEFAULT_LAG = 200_000 # 200kb
      DEFAULT_WAIT = 5 # seconds

      def start_sync(options)
        PgEasyReplicate.assert_config

        create_publication(
          group_name: options[:group_name],
          conn_string: source_db_url,
        )

        add_tables_to_publication(
          group_name: options[:group_name],
          tables: options[:tables],
          conn_string: source_db_url,
          schema: options[:schema],
        )

        create_subscription(
          group_name: options[:group_name],
          source_conn_string: secondary_source_db_url || source_db_url,
          target_conn_string: target_db_url,
        )

        Group.create(
          name: options[:group_name],
          table_names: options[:tables],
          schema_name: options[:schema],
          started_at: Time.now.utc,
        )
      rescue => e
        stop_sync(
          group_name: options[:group_name],
          source_conn_string: source_db_url,
          target_conn_string: target_db_url,
        )

        if Group.find(options[:group_name])
          Group.update(group_name: options[:group_name], failed_at: Time.now)
        else
          Group.create(
            name: options[:group_name],
            table_names: options[:tables],
            schema_name: options[:schema],
            started_at: Time.now.utc,
            failed_at: Time.now.utc,
          )
        end

        abort_with("Starting sync failed: #{e.message}")
      end

      def create_publication(group_name:, conn_string:)
        logger.info(
          "Setting up publication",
          { publication_name: publication_name(group_name) },
        )
        Query.run(
          query: "create publication #{publication_name(group_name)}",
          connection_url: conn_string,
        )
      end

      def add_tables_to_publication(
        schema:,
        group_name:,
        conn_string:,
        tables: ""
      )
        logger.info(
          "Adding tables up publication",
          { publication_name: publication_name(group_name) },
        )
        tables = tables&.split(",") || []
        unless tables.size > 0
          tables = list_all_tables(schema: schema, conn_string: conn_string)
        end

        tables.map do |table_name|
          Query.run(
            query:
              "ALTER PUBLICATION #{publication_name(group_name)} ADD TABLE \"#{table_name}\"",
            connection_url: conn_string,
            schema: schema,
          )
        end
      end

      def list_all_tables(schema:, conn_string:)
        Query
          .run(
            query:
              "SELECT table_name FROM information_schema.tables WHERE table_schema = '#{schema}'",
            connection_url: conn_string,
          )
          .map(&:values)
          .flatten
      end

      def drop_publication(group_name:, conn_string:)
        logger.info(
          "Dropping publication",
          { publication_name: publication_name(group_name) },
        )
        Query.run(
          query: "DROP PUBLICATION IF EXISTS #{publication_name(group_name)}",
          connection_url: conn_string,
        )
      end

      def create_subscription(
        group_name:,
        source_conn_string:,
        target_conn_string:
      )
        logger.info(
          "Setting up subscription",
          {
            publication_name: publication_name(group_name),
            subscription_name: subscription_name(group_name),
          },
        )

        Query.run(
          query:
            "CREATE SUBSCRIPTION #{subscription_name(group_name)} CONNECTION '#{source_conn_string}' PUBLICATION #{publication_name(group_name)}",
          connection_url: target_conn_string,
          transaction: false,
        )
      rescue Sequel::DatabaseError => e
        if e.message.include?("canceling statement due to statement timeout")
          abort_with(
            "Subscription creation failed, please ensure both databases are in the same network region: #{e.message}",
          )
        end

        raise
      end

      def drop_subscription(group_name:, target_conn_string:)
        logger.info(
          "Dropping subscription",
          {
            publication_name: publication_name(group_name),
            subscription_name: subscription_name(group_name),
          },
        )
        Query.run(
          query: "DROP SUBSCRIPTION IF EXISTS #{subscription_name(group_name)}",
          connection_url: target_conn_string,
          transaction: false,
        )
      end

      def stop_sync(target_conn_string:, source_conn_string:, group_name:)
        PgEasyReplicate.assert_config

        logger.info(
          "Stopping sync",
          {
            publication_name: publication_name(group_name),
            subscription_name: subscription_name(group_name),
          },
        )
        drop_publication(
          group_name: group_name,
          conn_string: source_conn_string,
        )
        drop_subscription(
          group_name: group_name,
          target_conn_string: target_conn_string,
        )
      end

      def switchover(group_name:, source_conn_string:, target_conn_string:)
        PgEasyReplicate.assert_config
        group = Group.find(group_name)

        watch_lag(group_name: group_name)
        revoke_connections_on_source_db(group_name)
        wait_for_remaining_catchup(group_name)
        refresh_sequences(
          conn_string: target_conn_string,
          schema: group[:schema_name],
        )
        mark_switchover_complete(group_name)
        drop_subscription(
          group_name: group_name,
          target_conn_string: target_conn_string,
        )
      rescue => e
        restore_connections_on_source_db(group_name)

        abort_with("Switchover sync failed: #{e.message}")
      end

      def watch_lag(group_name:, wait_time: DEFAULT_WAIT, lag: DEFAULT_LAG)
        logger.info("Watching lag stats")

        loop do
          sleep(wait_time)

          break if Stats.all_tables_replicating?(group_name)

          lag_stat = lag_stats.first
          if lag_stat[:write_lag].nil? || lag_stat[:flush_lag].nil? ||
               lag_stat[:replay_lag].nil?
            next
          end

          logger.debug("Current lag stats: #{lag_stat}")

          below_write_lag = lag_stat[:write_lag] <= lag
          below_flush_lag = lag_stat[:flush_lag] <= lag
          below_replay_lag = lag_stat[:replay_lag] <= lag

          break if below_write_lag && below_flush_lag && below_replay_lag
        end

        logger.info("Lag below #{DEFAULT_LAG} bytes. Continuing...")
      end

      def wait_for_remaining_catchup(group_name)
        logger.info("Waiting for remaining WAL to get flushed")

        watch_lag(group_name: group_name, lag: 0, wait_time: 0.2)

        logger.info("Caught up on remaining WAL lag")
      end

      def revoke_connections_on_source_db(group_name)
        logger.info(
          "Lag is now below #{DEFAULT_LAG}, marking source DB to read only",
        )

        alter_sql =
          "ALTER USER #{db_user(source_db_url)} set default_transaction_read_only = true"
        Query.run(query: alter_sql, connection_url: source_db_url)

        kill_sql =
          "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE usename = '#{db_user(source_db_url)}';"

        Query.run(query: kill_sql, connection_url: source_db_url)
      end

      def restore_connections_on_source_db(group_name)
        logger.info("Restoring connections")

        alter_sql =
          "ALTER USER #{db_user(source_db_url)} set default_transaction_read_only = false"
        Query.run(query: alter_sql, connection_url: source_db_url)
      end

      def refresh_sequences(conn_string:, schema: nil)
        logger.info("Refreshing sequences")
        sql = <<~SQL
          DO $$
          DECLARE
          i TEXT;
          BEGIN
            FOR i IN (
              SELECT 'SELECT SETVAL('
                  || quote_literal(quote_ident(PGT.schemaname) || '.' || quote_ident(S.relname))
                  || ', COALESCE(MAX(' ||quote_ident(C.attname)|| '), 1) ) FROM '
                  || quote_ident(PGT.schemaname)|| '.'||quote_ident(T.relname)|| ';'
                FROM pg_class AS S,
                    pg_depend AS D,
                    pg_class AS T,
                    pg_attribute AS C,
                    pg_tables AS PGT
              WHERE S.relkind = 'S'
                AND S.oid = D.objid
                AND D.refobjid = T.oid
                AND D.refobjid = C.attrelid
                AND D.refobjsubid = C.attnum
                AND T.relname = PGT.tablename
            ) LOOP
                EXECUTE i;
            END LOOP;
          END $$;
        SQL

        Query.run(query: sql, connection_url: conn_string, schema: schema)
      end

      def mark_switchover_complete(group_name)
        Group.update(group_name: group_name, switchover_completed_at: Time.now)
      end
    end
  end
end
