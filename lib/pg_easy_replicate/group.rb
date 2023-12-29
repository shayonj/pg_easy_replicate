# frozen_string_literal: true

module PgEasyReplicate
  class Group
    extend Helper
    class << self
      def setup
        conn =
          Query.connect(
            connection_url: source_db_url,
            schema: internal_schema_name,
          )
        return if conn.table_exists?("groups")
        conn.create_table("groups") do
          primary_key(:id)
          column(:name, String, null: false)
          column(:table_names, String, text: true)
          column(:schema_name, String)
          column(:created_at, Time, default: Sequel::CURRENT_TIMESTAMP)
          column(:updated_at, Time, default: Sequel::CURRENT_TIMESTAMP)
          column(:started_at, Time)
          column(:failed_at, Time)
          column(:recreate_indices_post_copy, TrueClass, default: true)
          column(:switchover_completed_at, Time)
        end
      ensure
        conn&.disconnect
      end

      def drop
        conn =
          Query.connect(
            connection_url: source_db_url,
            schema: internal_schema_name,
          ).drop_table?("groups")
      ensure
        conn&.disconnect
      end

      def create(options)
        groups.insert(
          name: options[:name],
          table_names: options[:table_names],
          schema_name: options[:schema_name],
          started_at: options[:started_at],
          failed_at: options[:failed_at],
        )
      rescue => e
        abort_with("Adding group entry failed: #{e.message}")
      end

      def update(
        group_name:,
        started_at: nil,
        switchover_completed_at: nil,
        failed_at: nil
      )
        set = {
          started_at: started_at&.utc,
          switchover_completed_at: switchover_completed_at&.utc,
          failed_at: failed_at&.utc,
          updated_at: Time.now.utc,
        }.compact
        groups.where(name: group_name).update(set)
      rescue => e
        abort_with("Updating group entry failed: #{e.message}")
      end

      def find(group_name)
        groups.first(name: group_name)
      rescue => e
        abort_with("Finding group entry failed: #{e.message}")
      end

      def delete(group_name)
        groups.where(name: group_name).delete
      rescue => e
        abort_with("Deleting group entry failed: #{e.message}")
      end

      private

      def groups
        conn =
          Query.connect(
            connection_url: source_db_url,
            schema: internal_schema_name,
          )
        conn[:groups]
      end
    end
  end
end
