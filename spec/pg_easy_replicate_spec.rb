# frozen_string_literal: true

RSpec.describe(PgEasyReplicate) do
  it "has a version number" do
    expect(PgEasyReplicate::VERSION).not_to be_nil
  end

  describe ".config" do
    it "returns the config for bother databases" do
      result = described_class.config
      expect(result).to eq(
        {
          source_db: [
            { "name" => "max_logical_replication_workers", "setting" => "4" },
            { "name" => "max_replication_slots", "setting" => "10" },
            { "name" => "max_wal_senders", "setting" => "10" },
            { "name" => "max_worker_processes", "setting" => "8" },
            { "name" => "wal_level", "setting" => "logical" },
          ],
          target_db: [
            { "name" => "max_logical_replication_workers", "setting" => "4" },
            { "name" => "max_replication_slots", "setting" => "10" },
            { "name" => "max_wal_senders", "setting" => "10" },
            { "name" => "max_worker_processes", "setting" => "8" },
            { "name" => "wal_level", "setting" => "logical" },
          ],
        },
      )
    end

    describe ".assert_confg" do
      let(:source_db_config_without_logical) do
        {
          source_db: [{ "name" => "wal_level", "setting" => "replication" }],
          target_db: [{ "name" => "wal_level", "setting" => "logical" }],
        }
      end

      let(:target_db_config_without_logical) do
        {
          source_db: [{ "name" => "wal_level", "setting" => "logical" }],
          target_db: [{ "name" => "wal_level", "setting" => "replication" }],
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
    end
  end
end
