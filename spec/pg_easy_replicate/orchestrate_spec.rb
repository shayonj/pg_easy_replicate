# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Orchestrate) do
  describe ".create_publication" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
    end

    after do
      teardown_tables
      described_class.drop_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
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
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
    end

    after do
      teardown_tables
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

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

    it "raises an error when user does not have sufficient privileges" do
      # Use a limited user for this test case
      restricted_user = "no_sup"
      restricted_user_connection_url = connection_url(restricted_user)

      described_class.create_publication(
        group_name: "cluster1",
        conn_string: connection_url,
      )

      expect do
        described_class.drop_publication(
          group_name: "cluster1",
          conn_string: restricted_user_connection_url,
        )
      end.to raise_error(RuntimeError) { |e|
        expect(e.message).to include("Unable to drop publication")
      }
      expect(pg_publications(connection_url: connection_url)).not_to eq([])
    end
  end

  describe ".add_tables_to_publication" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
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
      teardown_tables
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "successfully for all tables" do
      tables =
        described_class.determine_tables(
          schema: test_schema,
          conn_string: connection_url,
        )

      described_class.add_tables_to_publication(
        group_name: "cluster1",
        schema: test_schema,
        conn_string: connection_url,
        tables: tables,
      )

      expect(pg_publication_tables(connection_url: connection_url)).to contain_exactly({
            pubname: "pger_publication_cluster1",
            schemaname: "pger_test",
            tablename: "sellers",
          }, {
            pubname: "pger_publication_cluster1",
            schemaname: "pger_test",
            tablename: "items",
          })
    end

    it "succesfully for specific tables" do
      described_class.add_tables_to_publication(
        group_name: "cluster1",
        schema: test_schema,
        conn_string: connection_url,
        tables: ["sellers"],
      )

      expect(pg_publication_tables(connection_url: connection_url)).to contain_exactly({
            pubname: "pger_publication_cluster1",
            schemaname: "pger_test",
            tablename: "sellers",
          })
    end
  end

  describe ".list_all_tables" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
    end

    after do
      teardown_tables
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "succesfully" do
      r =
        described_class.list_all_tables(
          schema: test_schema,
          conn_string: connection_url,
        )
      expect(r.sort).to eq(%w[items sellers spatial_ref_sys])
    end
  end

  describe ".create_subscription" do
    before do
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })

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

      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
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
    before { PgEasyReplicate.bootstrap({ group_name: "cluster1" }) }

    after do
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
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

    it "raises an error when user does not have sufficient privileges" do
      # Use a limited user for this test case
      restricted_user = "no_sup"
      restricted_user_target_connection_url =
        target_connection_url(restricted_user)

      described_class.create_subscription(
        group_name: "cluster1",
        source_conn_string: docker_compose_source_connection_url,
        target_conn_string: target_connection_url,
      )

      expect do
        described_class.drop_subscription(
          group_name: "cluster1",
          target_conn_string: restricted_user_target_connection_url,
        )
      end.to raise_error(RuntimeError) { |e|
        expect(e.message).to include("Unable to drop subscription")
      }
      expect(pg_subscriptions(connection_url: target_connection_url)).not_to eq(
        [],
      )
    end
  end

  describe ".start_sync" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
    end

    after do
      described_class.stop_sync(
        group_name: "cluster1",
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
      )
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
      teardown_tables
    end

    it "successfully" do
      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      described_class.start_sync(
        group_name: "cluster1",
        schema_name: test_schema,
        recreate_indices_post_copy: false,
      )

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

      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        switchover_completed_at: nil,
        created_at: kind_of(Time),
        name: "cluster1",
        schema_name: "pger_test",
        id: kind_of(Integer),
        started_at: kind_of(Time),
        updated_at: kind_of(Time),
        failed_at: nil,
        table_names: "items,sellers",
        recreate_indices_post_copy: false,
      )
    end

    it "fails successfully" do
      allow(PgEasyReplicate::Orchestrate).to receive(
        :create_subscription,
      ).and_raise("boo")

      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      expect do
        described_class.start_sync(
          group_name: "cluster1",
          schema_name: test_schema,
          recreate_indices_post_copy: false,
        )
      end.to raise_error(RuntimeError, "Starting sync failed: boo")

      expect(pg_publications(connection_url: connection_url)).to eq([])

      expect(pg_subscriptions(connection_url: target_connection_url)).to eq([])

      expect(PgEasyReplicate::Group.find("cluster1")).to be_nil
    end
  end

  describe ".run_vacuum_analyze" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1", schema: test_schema })

      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      PgEasyReplicate::Orchestrate.start_sync(
        group_name: "cluster1",
        schema_name: test_schema,
        recreate_indices_post_copy: false,
      )
    end

    after do
      described_class.stop_sync(
        group_name: "cluster1",
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
      )
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
      teardown_tables
    end

    it "successfully" do
      expect(
        vacuum_stats(url: target_connection_url, schema: test_schema),
      ).to include(
        { last_analyze: nil, last_vacuum: nil, relname: "sellers" },
        { last_analyze: nil, last_vacuum: nil, relname: "items" },
      )

      described_class.run_vacuum_analyze(
        conn_string: target_connection_url,
        schema: test_schema,
        tables:
          PgEasyReplicate::Group.find("cluster1")[:table_names].split(","),
      )
      sleep 2

      expect(
        vacuum_stats(url: target_connection_url, schema: test_schema),
      ).to include(
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "sellers",
        },
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "items",
        },
      )

      expect(
        PgEasyReplicate::Query.run(
          query: "show statement_timeout",
          connection_url: target_connection_url,
          user: "james-bond",
        ),
      ).to eq([{ statement_timeout: "30s" }])
    end
  end

  describe ".switchover" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1", schema: test_schema })
    end

    after do
      teardown_tables
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "successfully" do
      conn1 =
        PgEasyReplicate::Query.connect(
          connection_url: connection_url,
          schema: test_schema,
        )
      conn1[:items].insert(name: "Foo1")
      expect(conn1[:items].first[:name]).to eq("Foo1")

      # Expect no item in target DB
      conn2 =
        PgEasyReplicate::Query.connect(
          connection_url: target_connection_url,
          schema: test_schema,
        )
      expect(conn2[:items].first).to be_nil

      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      described_class.start_sync(
        group_name: "cluster1",
        schema_name: test_schema,
        recreate_indices_post_copy: false,
      )

      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        switchover_completed_at: nil,
        created_at: kind_of(Time),
        name: "cluster1",
        schema_name: "pger_test",
        id: kind_of(Integer),
        started_at: kind_of(Time),
        updated_at: kind_of(Time),
        failed_at: nil,
        table_names: "items,sellers",
        recreate_indices_post_copy: false,
      )

      conn1[:items].insert(name: "Foo2")

      sleep 10

      expect(conn1[:items].map { |r| r[:name] }).to eq(%w[Foo1 Foo2])
      expect(conn2[:items].map { |r| r[:name] }).to eq(%w[Foo1 Foo2])

      # Sequence check
      expect(conn1.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
        [{ last_value: 2 }],
      )

      # Expect sequence to not be updated on target DB
      expect(conn2.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
        [{ last_value: 1 }],
      )

      described_class.switchover(
        group_name: "cluster1",
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
      )

      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        switchover_completed_at: kind_of(Time),
        created_at: kind_of(Time),
        name: "cluster1",
        schema_name: "pger_test",
        id: kind_of(Integer),
        started_at: kind_of(Time),
        updated_at: kind_of(Time),
        failed_at: nil,
        table_names: "items,sellers",
      )

      # Ensure index exists
      result =
        PgEasyReplicate::IndexManager.fetch_indices(
          conn_string: target_connection_url,
          tables: %w[sellers items],
          schema: test_schema,
        )

      expect(result).to eq(
        [
          {
            table_name: "items",
            index_name: "items_id_index",
            index_definition:
              "CREATE INDEX items_id_index ON pger_test.items USING btree (id)",
          },
          {
            table_name: "items",
            index_name: "items_seller_id_index",
            index_definition:
              "CREATE INDEX items_seller_id_index ON pger_test.items USING btree (seller_id)",
          },
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

      # Expect sequence to be updated on target DB
      expect(conn2.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
        [{ last_value: 2 }],
      )

      # restore connection so cleanup can happen
      described_class.restore_connections_on_source_db

      expect(
        vacuum_stats(url: target_connection_url, schema: test_schema),
      ).to include(
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "sellers",
        },
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "items",
        },
      )
    end

    it "successfully with no vacuum and analyze" do
      conn1 =
        PgEasyReplicate::Query.connect(
          connection_url: connection_url,
          schema: test_schema,
        )
      conn1[:items].insert(name: "Foo1")
      expect(conn1[:items].first[:name]).to eq("Foo1")

      # Expect no item in target DB
      conn2 =
        PgEasyReplicate::Query.connect(
          connection_url: target_connection_url,
          schema: test_schema,
        )
      expect(conn2[:items].first).to be_nil

      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      described_class.start_sync(
        group_name: "cluster1",
        schema_name: test_schema,
        recreate_indices_post_copy: false,
      )

      conn1[:items].insert(name: "Foo2")

      sleep 10

      expect(conn1[:items].map { |r| r[:name] }).to eq(%w[Foo1 Foo2])
      expect(conn2[:items].map { |r| r[:name] }).to eq(%w[Foo1 Foo2])

      described_class.switchover(
        group_name: "cluster1",
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
        skip_vacuum_analyze: true,
      )

      # restore connection so cleanup can happen
      described_class.restore_connections_on_source_db

      expect(
        vacuum_stats(url: target_connection_url, schema: test_schema),
      ).to include(
        { last_analyze: nil, last_vacuum: nil, relname: "sellers" },
        { last_analyze: nil, last_vacuum: nil, relname: "items" },
      )
    end

    it "successfully with exclude_tables" do
      conn1 =
        PgEasyReplicate::Query.connect(
          connection_url: connection_url,
          schema: test_schema,
        )
      conn1[:items].insert(name: "Foo1")
      expect(conn1[:items].first[:name]).to eq("Foo1")

      # Expect no item in target DB
      conn2 =
        PgEasyReplicate::Query.connect(
          connection_url: target_connection_url,
          schema: test_schema,
        )
      expect(conn2[:items].first).to be_nil

      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      described_class.start_sync(
        group_name: "cluster1",
        schema_name: test_schema,
        exclude_tables: ["sellers"],
        recreate_indices_post_copy: false,
      )

      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        switchover_completed_at: nil,
        created_at: kind_of(Time),
        name: "cluster1",
        schema_name: "pger_test",
        id: kind_of(Integer),
        started_at: kind_of(Time),
        updated_at: kind_of(Time),
        failed_at: nil,
        table_names: "items",
        recreate_indices_post_copy: false,
      )

      conn1[:items].insert(name: "Foo2")

      sleep 10

      expect(conn1[:items].map { |r| r[:name] }).to eq(%w[Foo1 Foo2])
      expect(conn2[:items].map { |r| r[:name] }).to eq(%w[Foo1 Foo2])

      # Sequence check
      expect(conn1.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
        [{ last_value: 2 }],
      )

      # Expect sequence to not be updated on target DB
      expect(conn2.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
        [{ last_value: 1 }],
      )

      described_class.switchover(
        group_name: "cluster1",
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
      )

      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        switchover_completed_at: kind_of(Time),
        created_at: kind_of(Time),
        name: "cluster1",
        schema_name: "pger_test",
        id: kind_of(Integer),
        started_at: kind_of(Time),
        updated_at: kind_of(Time),
        failed_at: nil,
        table_names: "items",
      )

      # Ensure index exists
      result =
        PgEasyReplicate::IndexManager.fetch_indices(
          conn_string: target_connection_url,
          tables: ["items"],
          schema: test_schema,
        )

      expect(result).to eq(
        [
          {
            table_name: "items",
            index_name: "items_id_index",
            index_definition:
              "CREATE INDEX items_id_index ON pger_test.items USING btree (id)",
          },
          {
            table_name: "items",
            index_name: "items_seller_id_index",
            index_definition:
              "CREATE INDEX items_seller_id_index ON pger_test.items USING btree (seller_id)",
          },
        ],
      )

      # Expect sequence to be updated on target DB
      expect(conn2.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
        [{ last_value: 2 }],
      )

      # restore connection so cleanup can happen
      described_class.restore_connections_on_source_db

      expect(
        vacuum_stats(url: target_connection_url, schema: test_schema),
      ).to include(
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "items",
        },
        { last_analyze: nil, last_vacuum: nil, relname: "sellers" },
        { last_analyze: nil, last_vacuum: nil, relname: "spatial_ref_sys" },
      )
    end

    it "does not mark switchover complete if subscription drop fails" do
      conn1 =
        PgEasyReplicate::Query.connect(
          connection_url: connection_url,
          schema: test_schema,
        )
      conn1[:items].insert(name: "Foo1")
      expect(conn1[:items].first[:name]).to eq("Foo1")

      conn2 =
        PgEasyReplicate::Query.connect(
          connection_url: target_connection_url,
          schema: test_schema,
        )
      expect(conn2[:items].first).to be_nil

      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      described_class.start_sync(
        group_name: "cluster1",
        schema_name: test_schema,
        recreate_indices_post_copy: false,
      )

      allow(described_class).to receive(:drop_subscription).and_raise(
        "Subscription drop failed",
      )

      expect do
        described_class.switchover(
          group_name: "cluster1",
          source_conn_string: connection_url,
          target_conn_string: target_connection_url,
          skip_vacuum_analyze: true,
        )
      end.to raise_error("Switchover failed: Subscription drop failed")

      described_class.restore_connections_on_source_db

      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        switchover_completed_at: nil,
      )

      RSpec::Mocks.space.proxy_for(described_class).reset

      described_class.switchover(
        group_name: "cluster1",
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
        skip_vacuum_analyze: true,
      )
      described_class.restore_connections_on_source_db
      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        switchover_completed_at: kind_of(Time),
      )
    end
  end

  # Note: Hard to test for special roles that act as superuser which aren't superuser, like rds_superuser
  # So all this spec does in vanilla postgres is to raise error below.
  describe ".switchover with special user role" do
    before do
      ENV["SOURCE_DB_URL"] = connection_url("james-bond_role_regular")
      ENV["TARGET_DB_URL"] = target_connection_url("james-bond_role_regular")

      setup_roles
      setup_tables("james-bond_role_regular")

      PgEasyReplicate.assert_config(
        special_user_role: "james-bond_super_role",
        schema_name: test_schema,
      )
      PgEasyReplicate.bootstrap(
        {
          group_name: "cluster1",
          schema: test_schema,
          special_user_role: "james-bond_super_role",
        },
      )
    end

    after do
      teardown_tables
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
      cleanup_roles

      ENV["SOURCE_DB_URL"] = connection_url
      ENV["TARGET_DB_URL"] = target_connection_url
    end

    it "successfully raises lack of super user error" do
      conn1 =
        PgEasyReplicate::Query.connect(
          connection_url: connection_url("james-bond_role_regular"),
          schema: test_schema,
          user: "james-bond_role_regular",
        )
      conn1[:items].insert(name: "Foo1")
      expect(conn1[:items].first[:name]).to eq("Foo1")

      # Expect no item in target DB
      conn2 =
        PgEasyReplicate::Query.connect(
          connection_url: target_connection_url("james-bond_role_regular"),
          schema: test_schema,
          user: "james-bond_role_regular",
        )
      expect(conn2[:items].first).to be_nil

      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url(
        "james-bond_super_role",
      )

      expect do
        described_class.start_sync(
          group_name: "cluster1",
          schema_name: test_schema,
          recreate_indices_post_copy: false,
        )
      end.to raise_error(/PG::InsufficientPrivilege/)

      # expect(PgEasyReplicate::Group.find("cluster1")).to include(
      #   switchover_completed_at: nil,
      #   created_at: kind_of(Time),
      #   name: "cluster1",
      #   schema_name: "pger_test",
      #   id: kind_of(Integer),
      #   started_at: kind_of(Time),
      #   updated_at: kind_of(Time),
      #   failed_at: nil,
      #   table_names: nil,
      # )

      # conn1[:items].insert(name: "Foo2")

      # sleep 10

      # expect(conn1[:items].map { |r| r[:name] }).to eq(%w[Foo1 Foo2])
      # expect(conn2[:items].map { |r| r[:name] }).to eq(%w[Foo1 Foo2])

      # # Sequence check
      # expect(conn1.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
      #   [{ last_value: 2 }],
      # )

      # # Expect sequence to not be updated on target DB
      # expect(conn2.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
      #   [{ last_value: 1 }],
      # )

      # described_class.switchover(
      #   group_name: "cluster1",
      #   source_conn_string: connection_url("james-bond_role_regular"),
      #   target_conn_string: target_connection_url("james-bond_role_regular"),
      # )

      # expect(PgEasyReplicate::Group.find("cluster1")).to include(
      #   switchover_completed_at: kind_of(Time),
      #   created_at: kind_of(Time),
      #   name: "cluster1",
      #   schema_name: "pger_test",
      #   id: kind_of(Integer),
      #   started_at: kind_of(Time),
      #   updated_at: kind_of(Time),
      #   failed_at: nil,
      #   table_names: nil,
      # )

      # # Expect sequence to be updated on target DB
      # expect(conn2.fetch("SELECT last_value FROM items_id_seq;").to_a).to eq(
      #   [{ last_value: 2 }],
      # )

      # # restore connection so cleanup can happen
      # described_class.restore_connections_on_source_db
    end
  end

  describe "excluding tables" do
    before do
      setup_tables
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
    end

    after do
      described_class.stop_sync(
        group_name: "cluster1",
        source_conn_string: connection_url,
        target_conn_string: target_connection_url,
      )
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
      teardown_tables
    end

    it "successfully excludes specific tables for replication" do
      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      described_class.start_sync(
        group_name: "cluster1",
        schema_name: test_schema,
        recreate_indices_post_copy: false,
        exclude_tables: ["items"],
      )

      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        table_names: "sellers",
      )
      expect(PgEasyReplicate::Group.find("cluster1")).not_to include(
        table_names: "items",
      )

      tables =
        described_class.determine_tables(
          schema: test_schema,
          conn_string: connection_url,
          exclude_list: ["items"],
        )

      expect(tables).to include("sellers")
      expect(tables).not_to include("items")
    end

    it "successfully includes tables for replication if exclude_tables is not set" do
      ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
      described_class.start_sync(
        group_name: "cluster1",
        schema_name: test_schema,
        recreate_indices_post_copy: false,
      )

      expect(PgEasyReplicate::Group.find("cluster1")).to include(
        table_names: "items,sellers",
      )

      tables =
        described_class.determine_tables(
          schema: test_schema,
          conn_string: connection_url,
        )
      expect(tables).to eq(%w[items sellers])
    end
  end
end
