# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::DDLManager) do
  let(:group_name) { "test_group" }
  let(:schema_name) { "public" }
  let(:conn_string) { "postgres://user:password@localhost:5432/testdb" }
  let(:source_conn_string) do
    "postgres://user:password@localhost:5432/sourcedb"
  end
  let(:target_conn_string) do
    "postgres://user:password@localhost:5432/targetdb"
  end

  describe ".setup_ddl_tracking" do
    it "calls DDLAudit.setup with the correct parameters" do
      expect(PgEasyReplicate::DDLAudit).to receive(:setup).with(group_name)

      described_class.setup_ddl_tracking(
        conn_string: conn_string,
        group_name: group_name,
        schema: schema_name,
      )
    end
  end

  describe ".cleanup_ddl_tracking" do
    it "calls DDLAudit.drop with the correct parameters" do
      expect(PgEasyReplicate::DDLAudit).to receive(:drop).with(group_name)

      described_class.cleanup_ddl_tracking(
        conn_string: conn_string,
        group_name: group_name,
        schema: schema_name,
      )
    end
  end

  describe ".list_ddl_changes" do
    it "calls DDLAudit.list_changes with the correct parameters" do
      limit = 50
      expect(PgEasyReplicate::DDLAudit).to receive(:list_changes).with(
        group_name,
        limit: limit,
      )

      described_class.list_ddl_changes(
        conn_string: conn_string,
        group_name: group_name,
        schema: schema_name,
        limit: limit,
      )
    end
  end

  describe ".apply_ddl_change" do
    it "calls DDLAudit.apply_change with the correct parameters" do
      id = 1
      expect(PgEasyReplicate::DDLAudit).to receive(:apply_change).with(
        source_conn_string,
        target_conn_string,
        group_name,
        id,
      )

      described_class.apply_ddl_change(
        source_conn_string: source_conn_string,
        target_conn_string: target_conn_string,
        group_name: group_name,
        id: id,
        schema: schema_name,
      )
    end
  end

  describe ".apply_all_ddl_changes" do
    it "calls DDLAudit.apply_all_changes with the correct parameters" do
      expect(PgEasyReplicate::DDLAudit).to receive(:apply_all_changes).with(
        source_conn_string,
        target_conn_string,
        group_name,
      )

      described_class.apply_all_ddl_changes(
        source_conn_string: source_conn_string,
        target_conn_string: target_conn_string,
        group_name: group_name,
        schema: schema_name,
      )
    end
  end
end
