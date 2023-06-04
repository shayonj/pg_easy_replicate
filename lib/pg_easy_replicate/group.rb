# frozen_string_literal: true

module PgEasyReplicate
  class Group
    extend Helper
    class << self
      def setup
        conn =
          PgEasyReplicate::Query.connect(source_db_url, internal_schema_name)
        conn.create_table("groups") do
          primary_key(:id)
          column(:name, String, null: false)
          column(:table_names, String, text: true)
          column(:schema_name, String)
          column(:created_at, Time, default: Sequel::CURRENT_TIMESTAMP)
          column(:started_at, Time, default: Sequel::CURRENT_TIMESTAMP)
          column(:completed_at, Time)
        end
      end

      def drop
        PgEasyReplicate::Query.connect(
          source_db_url,
          internal_schema_name,
        ).drop_table?("groups")
      end

      def create(options)
        groups.insert(
          name: options[:name],
          table_names: options[:table_names],
          schema_name: options[:schema_name],
        )
      rescue => e
        abort_with("Adding group entry failed: #{e.message}")
      end

      def update(group_name:, started_at: nil, completed_at: nil)
        groups.where(name: group_name).update(
          started_at: started_at&.utc,
          completed_at: completed_at&.utc,
        )
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
          PgEasyReplicate::Query.connect(source_db_url, internal_schema_name)
        conn[:groups]
      end
    end
  end
end
