# frozen_string_literal: true

RSpec.describe(PgEasyReplicate) do
  it "has a version number" do
    expect(PgEasyReplicate::VERSION).not_to be_nil
  end

  describe ".config" do
    it "returns the config for both databases" do
      result = described_class.config
      expect(result).to eq(
        {
          source_db_is_super_user: true,
          target_db_is_super_user: true,
          source_db: [
            { name: "max_logical_replication_workers", setting: "4" },
            { name: "max_replication_slots", setting: "10" },
            { name: "max_wal_senders", setting: "10" },
            { name: "max_worker_processes", setting: "8" },
            { name: "wal_level", setting: "logical" },
          ],
          target_db: [
            { name: "max_logical_replication_workers", setting: "4" },
            { name: "max_replication_slots", setting: "10" },
            { name: "max_wal_senders", setting: "10" },
            { name: "max_worker_processes", setting: "8" },
            { name: "wal_level", setting: "logical" },
          ],
          pg_dump_exists: true,
        },
      )
    end

    describe ".assert_confg" do
      let(:source_db_config_without_logical) do
        {
          source_db: [{ name: "wal_level", setting: "replication" }],
          target_db: [{ name: "wal_level", setting: "logical" }],
        }
      end

      let(:target_db_config_without_logical) do
        {
          source_db: [{ name: "wal_level", setting: "logical" }],
          target_db: [{ name: "wal_level", setting: "replication" }],
        }
      end

      it "raises wal level not being logical error for source db" do
        allow(described_class).to receive(:config).and_return(
          source_db_config_without_logical,
        )
        expect { described_class.assert_config }.to raise_error(
          "WAL_LEVEL should be LOGICAL on source DB",
        )
      end

      it "raises wal level not being logical error for target db" do
        allow(described_class).to receive(:config).and_return(
          target_db_config_without_logical,
        )
        expect { described_class.assert_config }.to raise_error(
          "WAL_LEVEL should be LOGICAL on target DB",
        )
      end

      it "raises when user is not superuser on source db" do
        allow(described_class).to receive(:config).and_return(
          {
            source_db_is_super_user: false,
            target_db: [{ name: "wal_level", setting: "logical" }],
            source_db: [{ name: "wal_level", setting: "logical" }],
          },
        )
        expect { described_class.assert_config }.to raise_error(
          "User on source database does not have super user privilege",
        )
      end

      it "raises when user is not superuser on target db" do
        allow(described_class).to receive(:config).and_return(
          {
            source_db_is_super_user: true,
            target_db_is_super_user: false,
            target_db: [{ name: "wal_level", setting: "logical" }],
            source_db: [{ name: "wal_level", setting: "logical" }],
          },
        )
        expect { described_class.assert_config }.to raise_error(
          "User on target database does not have super user privilege",
        )
      end

      it "raises error when copy schema is present and pg_dump is not" do
        allow(described_class).to receive(:config).and_return(
          {
            source_db_is_super_user: true,
            target_db_is_super_user: true,
            target_db: [{ name: "wal_level", setting: "logical" }],
            source_db: [{ name: "wal_level", setting: "logical" }],
            pg_dump_exists: false,
          },
        )

        expect {
          described_class.assert_config(copy_schema: true)
        }.to raise_error("pg_dump must exist if copy_schema (-c) is passed")
      end
    end

    describe ".is_super_user?" do
      before { setup_roles }
      after { cleanup_roles }

      it "returns true" do
        expect(described_class.send(:is_super_user?, connection_url)).to be(
          true,
        )
      end

      it "returns true with non primary user" do
        expect(
          described_class.send(
            :is_super_user?,
            connection_url("jamesbond_sup"),
          ),
        ).to be(true)
      end

      it "returns false" do
        expect(
          described_class.send(:is_super_user?, connection_url("no_sup")),
        ).to be(false)
      end

      it "returns true if user is part of the special user role" do
        expect(
          described_class.send(
            :is_super_user?,
            connection_url("jamesbond_role_regular"),
            "jamesbond_super_role",
          ),
        ).to be(true)
      end
    end

    describe ".setup_internal_schema" do
      it "sets up the schema" do
        described_class.setup_internal_schema

        expect(get_schema).to eq([{ schema_name: "pger" }])
      end
    end

    describe ".drop_internal_schema" do
      before { described_class.bootstrap({ group_name: "cluster1" }) }

      after do
        described_class.cleanup({ everything: true, group_name: "cluster1" })
      end

      it "drops up the schema" do
        described_class.setup_internal_schema
        described_class.drop_internal_schema

        expect(get_schema).to eq([])
      end
    end

    describe ".bootstrap" do
      before { setup_tables("jamesbond", setup_target_db: false) }

      after do
        described_class.cleanup({ everything: true, group_name: "cluster1" })
        teardown_tables
        `rm #{PgEasyReplicate::SCHEMA_FILE_LOCATION}`
      end

      it "successfully with everything" do
        described_class.bootstrap({ group_name: "cluster1" })

        # Check schema exists
        expect(get_schema).to eq([{ schema_name: "pger" }])

        # Check table exists
        expect(groups_table_exists?).to eq([{ table_name: "groups" }])

        # Check user on source database
        expect(
          user_permissions(
            connection_url: connection_url,
            group_name: "cluster1",
          ),
        ).to eq(
          [
            {
              rolcanlogin: true,
              rolcreatedb: true,
              rolcreaterole: true,
              rolsuper: true,
            },
          ],
        )

        # Check user exists on target database
        expect(
          user_permissions(
            connection_url: target_connection_url,
            group_name: "cluster1",
          ),
        ).to eq(
          [
            {
              rolcanlogin: true,
              rolcreatedb: true,
              rolcreaterole: true,
              rolsuper: true,
            },
          ],
        )
      end

      it "successfully with copy_schema" do
        described_class.bootstrap({ group_name: "cluster1", copy_schema: true })

        # Check schema exists
        expect(get_schema).to eq([{ schema_name: "pger" }])

        # Check table exists
        expect(groups_table_exists?).to eq([{ table_name: "groups" }])

        # Check user on source database
        expect(
          user_permissions(
            connection_url: connection_url,
            group_name: "cluster1",
          ),
        ).to eq(
          [
            {
              rolcanlogin: true,
              rolcreatedb: true,
              rolcreaterole: true,
              rolsuper: true,
            },
          ],
        )

        # Check user exists on target database
        expect(
          user_permissions(
            connection_url: target_connection_url,
            group_name: "cluster1",
          ),
        ).to eq(
          [
            {
              rolcanlogin: true,
              rolcreatedb: true,
              rolcreaterole: true,
              rolsuper: true,
            },
          ],
        )

        conn =
          PgEasyReplicate::Query.connect(
            connection_url: target_connection_url,
            schema: test_schema,
            user: "jamesbond",
          )
        expect(conn.fetch("SELECT * FROM items").to_a).to eq([])
      end
    end

    describe ".cleanup" do
      it "successfully with everything" do
        described_class.bootstrap({ group_name: "cluster1" })
        ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
        PgEasyReplicate::Orchestrate.start_sync({ group_name: "cluster1" })
        described_class.cleanup({ everything: true, group_name: "cluster1" })

        # Check schema exists
        expect(get_schema).to eq([])

        # Check table exists
        expect(groups_table_exists?).to eq([])

        # Check user on source database
        expect(
          user_permissions(
            connection_url: connection_url,
            group_name: "cluster1",
          ),
        ).to eq([])

        # Check user exists on target database
        expect(
          user_permissions(
            connection_url: target_connection_url,
            group_name: "cluster1",
          ),
        ).to eq([])

        expect(pg_publications(connection_url: connection_url)).to eq([])
        expect(pg_subscriptions(connection_url: target_connection_url)).to eq(
          [],
        )
      end
    end

    describe ".export_schema" do
      before { setup_tables }

      after do
        teardown_tables
        `rm #{PgEasyReplicate::SCHEMA_FILE_LOCATION}`
      end

      it "succesfully" do
        described_class.export_schema(conn_string: connection_url)
        file_contents = File.read(PgEasyReplicate::SCHEMA_FILE_LOCATION)
        expect(file_contents).to match(/PostgreSQL database dump complete/)
      end

      it "raises error" do
        expect {
          described_class.export_schema(conn_string: "postgres://foo@bar")
        }.to raise_error(
          /Unable to export schema: pg_dump: error: could not translate host name "bar"/,
        )
      end
    end

    describe ".import_schema" do
      before { setup_tables("jamesbond", setup_target_db: false) }

      after do
        teardown_tables
        `rm #{PgEasyReplicate::SCHEMA_FILE_LOCATION}`
      end

      it "succesfully" do
        described_class.export_schema(conn_string: connection_url)
        described_class.import_schema(conn_string: target_connection_url)

        conn =
          PgEasyReplicate::Query.connect(
            connection_url: target_connection_url,
            schema: test_schema,
            user: "jamesbond",
          )
        expect(conn.fetch("SELECT * FROM items").to_a).to eq([])
      end

      it "raises error" do
        expect {
          described_class.import_schema(conn_string: "postgres://foo@bar")
        }.to raise_error(
          /Unable to import schema: psql: error: could not translate host name "bar"/,
        )
      end
    end
  end
end
