# frozen_string_literal: true

module PgEasyReplicate
  module DDLManager
    extend Helper

    class << self
      def setup_ddl_tracking(
        group_name:, conn_string: source_db_url,
        schema: "public"
      )
        DDLAudit.setup(group_name)
      end

      def cleanup_ddl_tracking(
        group_name:, conn_string: source_db_url,
        schema: "public"
      )
        DDLAudit.drop(group_name)
      end

      def list_ddl_changes(
        group_name:, conn_string: source_db_url,
        schema: "public",
        limit: 100
      )
        DDLAudit.list_changes(group_name, limit: limit)
      end

      def apply_ddl_change(
        group_name:, id:, source_conn_string: source_db_url,
        target_conn_string: target_db_url,
        schema: "public"
      )
        DDLAudit.apply_change(
          source_conn_string,
          target_conn_string,
          group_name,
          id,
        )
      end

      def apply_all_ddl_changes(
        group_name:, source_conn_string: source_db_url,
        target_conn_string: target_db_url,
        schema: "public"
      )
        DDLAudit.apply_all_changes(
          source_conn_string,
          target_conn_string,
          group_name,
        )
      end
    end
  end
end
