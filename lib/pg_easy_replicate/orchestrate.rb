# frozen_string_literal: true

module PgEasyReplicate
  class Orchestrate
    extend Helper

    class << self
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
      rescue => e
        stop_sync(
          group_name: options[:group_name],
          source_conn_string: source_db_url,
          target_conn_string: target_db_url,
        )

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

      def switchover
        assert_config
        # assert subscription publication is setup
      end
    end
  end
end
