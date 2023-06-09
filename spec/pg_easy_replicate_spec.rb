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
          source_db_is_superuser: true,
          target_db_is_superuser: true,
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
            source_db_is_superuser: false,
            target_db: [{ name: "wal_level", setting: "logical" }],
            source_db: [{ name: "wal_level", setting: "logical" }],
          },
        )
        expect { described_class.assert_config }.to raise_error(
          "User on source database should be a superuser",
        )
      end

      it "raises when user is not superuser on target db" do
        allow(described_class).to receive(:config).and_return(
          {
            source_db_is_superuser: true,
            target_db_is_superuser: false,
            target_db: [{ name: "wal_level", setting: "logical" }],
            source_db: [{ name: "wal_level", setting: "logical" }],
          },
        )
        expect { described_class.assert_config }.to raise_error(
          "User on target database should be a superuser",
        )
      end
    end

    describe ".setup_schema" do
      it "sets up the schema" do
        described_class.setup_schema

        expect(get_schema).to eq([{ schema_name: "pger" }])
      end
    end

    describe ".drop_schema" do
      it "drops up the schema" do
        described_class.setup_schema
        described_class.drop_schema

        expect(get_schema).to eq([])
      end
    end

    describe ".bootstrap" do
      after do
        described_class.cleanup({ everything: true, group_name: "cluster1" })
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
    end

    describe ".cleanup" do
      it "successfully with everything" do
        described_class.bootstrap({ group_name: "cluster1" })
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
  end
end
