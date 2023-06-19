# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Orchestrate) do
  before { setup_tables }
  after { teardown_tables }

  describe ".create_publication" do
    after do
      described_class.drop_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )
    end

    it "succesfully" do
      described_class.create_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )

      expect(pg_publications(connection_url: connection_url)).to eq(
        [{ pubname: "pger_publication_cluster1" }],
      )
    end
  end

  describe ".drop_publication" do
    it "succesfully" do
      described_class.create_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )
      described_class.drop_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )

      expect(pg_publications(connection_url: connection_url)).to eq([])
    end
  end

  describe ".add_tables_to_publication" do
    before do
      described_class.create_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )
    end

    after do
      described_class.drop_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )
    end

    it "succesfully for all tables" do
      described_class.add_tables_to_publication(
        group_name: "cluster1",
        schema: test_schema,
        conn_string: connection_url,
      )

      expect(pg_publication_tables(connection_url: connection_url)).to eq(
        [
          {
            pubname: "pger_publication_cluster1",
            schemaname: "pger_test",
            tablename: "sellers",
          },
          {
            pubname: "pger_publication_cluster1",
            schemaname: "pger_test",
            tablename: "items",
          },
        ],
      )
    end

    it "succesfully for specific tables" do
      described_class.add_tables_to_publication(
        group_name: "cluster1",
        schema: test_schema,
        conn_string: connection_url,
        tables: "sellers,",
      )

      expect(pg_publication_tables(connection_url: connection_url)).to eq(
        [
          {
            pubname: "pger_publication_cluster1",
            schemaname: "pger_test",
            tablename: "sellers",
          },
        ],
      )
    end
  end

  describe ".list_all_tables" do
    it "succesfully" do
      r =
        described_class.list_all_tables(
          schema: test_schema,
          conn_string: connection_url,
        )
      expect(r).to match_array(%w[sellers items])
    end
  end

  describe ".create_subscription" do
    before do
      described_class.create_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )
    end

    after do
      described_class.drop_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )

      described_class.drop_subscription(
        group_name: "cluster1",
        target_conn_string: target_connection_url,
      )
    end

    it "succesfully" do
      described_class.create_subscription(
        group_name: "cluster1",
        source_conn_string: docker_compose_source_connection_url,
        target_conn_string: target_connection_url,
      )

      expect(pg_subscriptions(connection_url: target_connection_url)).to eq(
        [
          {
            subenabled: true,
            subname: "pger_subscription_cluster1",
            subpublications: "{pger_publication_cluster1}",
            subslotname: "pger_subscription_cluster1",
          },
        ],
      )
    end
  end

  describe ".drop_subscription" do
    before do
      described_class.create_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )
    end

    after do
      described_class.drop_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )
    end

    it "succesfully" do
      described_class.create_subscription(
        group_name: "cluster1",
        source_conn_string: docker_compose_source_connection_url,
        target_conn_string: target_connection_url,
      )
      described_class.drop_subscription(
        group_name: "cluster1",
        target_conn_string: target_connection_url,
      )

      expect(pg_subscriptions(connection_url: target_connection_url)).to eq([])
    end
  end

  describe ".start_sync" do # TODO add schema
    after do
      described_class.stop_sync(
        group_name: "cluster1",
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
      )
    end

    it "succesfully" do
      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      described_class.start_sync({ group_name: "cluster1" })

      expect(pg_publications(connection_url: connection_url)).to eq(
        [{ pubname: "pger_publication_cluster1" }],
      )

      expect(pg_subscriptions(connection_url: target_connection_url)).to eq(
        [
          {
            subenabled: true,
            subname: "pger_subscription_cluster1",
            subpublications: "{pger_publication_cluster1}",
            subslotname: "pger_subscription_cluster1",
          },
        ],
      )
    end
  end
end
