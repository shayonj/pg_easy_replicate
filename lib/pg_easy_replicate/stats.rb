# frozen_string_literal: true

module PgEasyReplicate
  class Stats
    REPLICATION_STATE_MAP = {
      "i" => "initializing",
      "d" => "data_is_being_copied",
      "f" => "finished_table_copy",
      "s" => "synchronized",
      "r" => "replicating",
    }.freeze
    extend Helper

    class << self
      def object(group_name)
        stats = replication_stats(group_name)
        group = Group.find(group_name)
        {
          lag_stats: lag_stats(group_name),
          replication_slots: pg_replication_slots(group_name),
          replication_stats: stats,
          replication_stats_count_by_state:
            replication_stats_count_by_state(stats),
          message_lsn_receipts: message_lsn_receipts(group_name),
          sync_started_at: group[:started_at],
          sync_failed_at: group[:failed_at],
          switchover_completed_at: group[:switchover_completed_at],
        }
      end

      def print(group_name)
        puts JSON.pretty_generate(object(group_name))
      end

      def follow(group_name)
        loop do
          print(group_name)
          sleep(1)
        end
      end

      # Get
      def lag_stats(group_name)
        sql = <<~SQL
          SELECT pid,
          client_addr,
          usename as user_name,
          application_name,
          state,
          sync_state,
          pg_wal_lsn_diff(sent_lsn, write_lsn) AS write_lag,
          pg_wal_lsn_diff(sent_lsn, flush_lsn) AS flush_lag,
          pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag
          FROM pg_stat_replication
          WHERE application_name = '#{subscription_name(group_name)}';
        SQL

        Query.run(query: sql, connection_url: source_db_url)
      end

      def pg_replication_slots(group_name)
        sql = <<~SQL
         select * from pg_replication_slots WHERE slot_name = '#{subscription_name(group_name)}';
        SQL

        Query.run(query: sql, connection_url: source_db_url)
      end

      def replication_stats(group_name)
        sql = <<~SQL
          SELECT
          s.subname AS subscription_name,
          c.relnamespace :: regnamespace :: text as table_schema,
          c.relname as table_name,
          rel.srsubstate as replication_state
        FROM
          pg_catalog.pg_subscription s
          JOIN pg_catalog.pg_subscription_rel rel ON rel.srsubid = s.oid
          JOIN pg_catalog.pg_class c on c.oid = rel.srrelid
        WHERE s.subname = '#{subscription_name(group_name)}'
        SQL

        Query
          .run(query: sql, connection_url: target_db_url)
          .each do |obj|
            obj[:replication_state] = REPLICATION_STATE_MAP[
              obj[:replication_state]
            ]
          end
      end

      def all_tables_replicating?(group_name)
        result =
          replication_stats(group_name)
            .each
            .with_object(Hash.new(0)) do |state, counts|
              counts[state[:replication_state]] += 1
            end
        result.keys.uniq.count == 1 &&
          result.keys.first == REPLICATION_STATE_MAP["r"]
      end

      def replication_stats_count_by_state(stats)
        stats
          .each
          .with_object(Hash.new(0)) do |state, counts|
            counts[state[:replication_state]] += 1
          end
      end

      def message_lsn_receipts(group_name)
        sql = <<~SQL
          select
          received_lsn,
          last_msg_send_time,
          last_msg_receipt_time,
          latest_end_lsn,
          latest_end_time
          from
            pg_catalog.pg_stat_subscription
          WHERE subname = '#{subscription_name(group_name)}'
        SQL
        Query.run(query: sql, connection_url: target_db_url)
      end
    end
  end
end
