# frozen_string_literal: true

require "spec_helper"

RSpec.describe(PgEasyReplicate::IndexManager) do
  describe ".fetch_indices" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
    end

    after do
      teardown_tables
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "fetches index information from the given connection string with no unique & PK indices" do
      result =
        described_class.fetch_indices(
          conn_string: connection_url,
          tables: "sellers, items",
          schema: test_schema,
        )

      expect(result).to eq(
        [
          {
            table_name: "sellers",
            index_name: "sellers_id_index",
            index_definition:
              "CREATE INDEX sellers_id_index ON pger_test.sellers USING btree (id)",
          },
          {
            table_name: "sellers",
            index_name: "sellers_last_login_index",
            index_definition:
              "CREATE INDEX sellers_last_login_index ON pger_test.sellers USING btree (last_login)",
          },
        ],
      )
    end
  end

  describe ".drop_indices" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
    end

    after do
      teardown_tables
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "drops non-primary + unique indices from the target database" do
      # Ensure index exists
      result =
        described_class.fetch_indices(
          conn_string: target_connection_url,
          tables: "sellers, items",
          schema: test_schema,
        )

      expect(result).to eq(
        [
          {
            table_name: "sellers",
            index_name: "sellers_id_index",
            index_definition:
              "CREATE INDEX sellers_id_index ON pger_test.sellers USING btree (id)",
          },
          {
            table_name: "sellers",
            index_name: "sellers_last_login_index",
            index_definition:
              "CREATE INDEX sellers_last_login_index ON pger_test.sellers USING btree (last_login)",
          },
        ],
      )

      described_class.drop_indices(
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
        tables: "sellers, items",
        schema: test_schema,
      )

      result =
        described_class.fetch_indices(
          conn_string: target_connection_url,
          tables: "sellers, items",
          schema: test_schema,
        )

      expect(result).to eq([])
    end
  end

  describe ".recreate_indices" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
    end

    after do
      teardown_tables
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "recreates indices on the target database concurrently" do
      # Ensure index exists
      result =
        described_class.fetch_indices(
          conn_string: target_connection_url,
          tables: "sellers, items",
          schema: test_schema,
        )

      expect(result).to eq(
        [
          {
            table_name: "sellers",
            index_name: "sellers_id_index",
            index_definition:
              "CREATE INDEX sellers_id_index ON pger_test.sellers USING btree (id)",
          },
          {
            table_name: "sellers",
            index_name: "sellers_last_login_index",
            index_definition:
              "CREATE INDEX sellers_last_login_index ON pger_test.sellers USING btree (last_login)",
          },
        ],
      )

      described_class.drop_indices(
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
        tables: "sellers, items",
        schema: test_schema,
      )

      # Ensure index is gone

      result =
        described_class.fetch_indices(
          conn_string: target_connection_url,
          tables: "sellers, items",
          schema: test_schema,
        )

      expect(result).to eq([])

      described_class.recreate_indices(
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
        tables: "sellers, items",
        schema: test_schema,
      )

      # Ensure index exists
      result =
        described_class.fetch_indices(
          conn_string: target_connection_url,
          tables: "sellers, items",
          schema: test_schema,
        )

      expect(result).to eq(
        [
          {
            table_name: "sellers",
            index_name: "sellers_id_index",
            index_definition:
              "CREATE INDEX sellers_id_index ON pger_test.sellers USING btree (id)",
          },
          {
            table_name: "sellers",
            index_name: "sellers_last_login_index",
            index_definition:
              "CREATE INDEX sellers_last_login_index ON pger_test.sellers USING btree (last_login)",
          },
        ],
      )
    end
  end

  describe ".wait_for_replication_completion" do
    it "waits until all tables are replicating" do
      allow(PgEasyReplicate::Stats).to receive(
        :all_tables_replicating?,
      ).and_return(false, false, true)

      expect(described_class).to receive(:sleep).with(5).twice
      described_class.wait_for_replication_completion(group_name: "group_name")

      expect(PgEasyReplicate::Stats).to have_received(:all_tables_replicating?)
        .with("group_name")
        .exactly(3)
        .times
    end
  end
end
