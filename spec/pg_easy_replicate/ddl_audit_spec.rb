# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::DDLAudit) do
  let(:schema_name) { "pger_test" }
  let(:group_name) { "cluster1" }

  before do
    setup_tables
    PgEasyReplicate.bootstrap({ group_name: group_name })
    PgEasyReplicate::Group.create(
      name: group_name,
      table_names: "sellers,items",
      schema_name: schema_name,
      started_at: Time.now.utc,
    )
  end

  after do
    teardown_tables
    PgEasyReplicate.cleanup({ everything: true })
  end

  describe ".setup" do
    it "creates the DDL audit table and triggers" do
      described_class.setup(group_name)

      trigger_status =
        PgEasyReplicate::Query.run(
          query:
            "SELECT evtenabled FROM pg_event_trigger WHERE evtname = 'pger_ddl_trigger_#{group_name}'",
          connection_url: connection_url,
        ).first
      puts "Debug: Trigger status - #{trigger_status.inspect}"

      table_exists =
        ddl_audit_table_exists?(nil, described_class.send(:table_name))
      expect(table_exists).to be(true)

      trigger_function_exists =
        function_exists?("pger_ddl_trigger_#{group_name}")
      expect(trigger_function_exists).to be(true)

      event_triggers_exist = event_triggers_exist?(group_name)
      expect(event_triggers_exist).to be(true)
    end

    it "doesn't create the table if it already exists" do
      described_class.setup(group_name)
      expect { described_class.setup(group_name) }.not_to raise_error
      expect(table_exists?(described_class.send(:table_name))).to be(true)
    end
  end

  describe ".drop" do
    before { described_class.setup(group_name) }

    it "drops the DDL audit table, triggers, and function" do
      described_class.drop(group_name)

      table_exists = table_exists?(described_class.send(:table_name))
      expect(table_exists).to be(true) # Table should still exist, only group-specific data is deleted

      trigger_function_exists =
        function_exists?("pger_ddl_trigger_#{group_name}")
      expect(trigger_function_exists).to be(false)

      event_triggers_exist = event_triggers_exist?(group_name)
      expect(event_triggers_exist).to be(false)
    end
  end

  describe "DDL change capture" do
    before { described_class.setup(group_name) }

    it "captures ALTER TABLE DDL for tables in the group" do
      execute_ddl(
        "ALTER TABLE #{schema_name}.sellers ADD COLUMN test_column VARCHAR(255)",
      )

      changes = described_class.list_changes(group_name)
      expect(changes.size).to eq(1)
      expect(changes.first[:event_type]).to eq("ddl_command_end")
      expect(changes.first[:object_type]).to eq("table")
      expect(changes.first[:object_identity]).to eq("#{schema_name}.sellers")
      expect(changes.first[:ddl_command]).to include("ALTER TABLE")
      expect(changes.first[:ddl_command]).to include("ADD COLUMN test_column")
    end

    it "captures CREATE INDEX DDL for tables in the group" do
      execute_ddl(
        "CREATE INDEX idx_sellers_name ON #{schema_name}.sellers (name)",
      )

      changes = described_class.list_changes(group_name)
      expect(changes.size).to eq(1)
      expect(changes.first[:event_type]).to eq("ddl_command_end")
      expect(changes.first[:object_type]).to eq("index")
      expect(changes.first[:object_identity]).to eq(
        "#{schema_name}.idx_sellers_name",
      )
      expect(changes.first[:ddl_command]).to include("CREATE INDEX")
      expect(changes.first[:ddl_command]).to include(
        "ON #{schema_name}.sellers",
      )
    end

    it "does not capture DDL for tables not in the group" do
      execute_ddl(
        "CREATE TABLE #{schema_name}.not_in_group (id serial PRIMARY KEY)",
      )

      described_class.list_changes(group_name)

      execute_ddl(
        "ALTER TABLE #{schema_name}.not_in_group ADD COLUMN test_column VARCHAR(255)",
      )

      changes = described_class.list_changes(group_name)
      expect(changes.size).to eq(0)

      execute_ddl("DROP TABLE #{schema_name}.not_in_group")
    end

    it "captures CREATE and DROP INDEX DDL for tables in the group" do
      execute_ddl(
        "CREATE INDEX idx_sellers_name ON #{schema_name}.sellers (name)",
      )

      execute_ddl("DROP INDEX #{schema_name}.idx_sellers_name")

      changes = described_class.list_changes(group_name)

      expect(changes.size).to eq(2)

      create_index_change =
        changes.find { |c| c[:ddl_command].include?("CREATE INDEX") }
      drop_index_change =
        changes.find { |c| c[:ddl_command].include?("DROP INDEX") }

      expect(create_index_change).not_to be_nil
      expect(create_index_change[:event_type]).to eq("ddl_command_end")
      expect(create_index_change[:object_type]).to eq("index")
      expect(create_index_change[:object_identity]).to eq(
        "#{schema_name}.idx_sellers_name",
      )
      expect(create_index_change[:ddl_command]).to include("CREATE INDEX")
      expect(create_index_change[:ddl_command]).to include(
        "ON #{schema_name}.sellers",
      )

      expect(drop_index_change).not_to be_nil
      expect(drop_index_change[:event_type]).to eq("sql_drop")
      expect(drop_index_change[:object_type]).to eq("index")
      expect(drop_index_change[:object_identity]).to eq(
        "#{schema_name}.idx_sellers_name",
      )
      expect(drop_index_change[:ddl_command]).to include("DROP INDEX")
    end

    it "captures ALTER TABLE DDL for adding and renaming a column" do
      execute_ddl(
        "ALTER TABLE #{schema_name}.sellers ADD COLUMN temp_email VARCHAR(255)",
      )
      execute_ddl(
        "ALTER TABLE #{schema_name}.sellers RENAME COLUMN temp_email TO permanent_email",
      )

      changes = described_class.list_changes(group_name)

      expect(changes.size).to eq(2)

      sorted_changes = changes.sort_by { |change| change[:created_at] }

      add_column_change = sorted_changes[0]
      rename_column_change = sorted_changes[1]

      expect(add_column_change[:event_type]).to eq("ddl_command_end")
      expect(add_column_change[:object_type]).to eq("table")
      expect(add_column_change[:object_identity]).to eq(
        "#{schema_name}.sellers",
      )
      expect(add_column_change[:ddl_command]).to include("ALTER TABLE")
      expect(add_column_change[:ddl_command]).to include(
        "ADD COLUMN temp_email",
      )

      expect(rename_column_change[:event_type]).to eq("ddl_command_end")
      expect(rename_column_change[:object_type]).to eq("table column")
      expect(rename_column_change[:object_identity]).to eq(
        "#{schema_name}.sellers.permanent_email",
      )
      expect(rename_column_change[:ddl_command]).to include("ALTER TABLE")
      expect(rename_column_change[:ddl_command]).to include(
        "RENAME COLUMN temp_email TO permanent_email",
      )
    end
  end

  describe ".list_changes" do
    before do
      described_class.setup(group_name)
      execute_ddl(
        "ALTER TABLE #{schema_name}.sellers ADD COLUMN email VARCHAR(255)",
      )
    end

    it "lists DDL changes for the specific group" do
      changes = described_class.list_changes(group_name)

      expect(changes.size).to eq(1)
      expect(changes.first.keys).to match_array(
        %i[
          id
          group_name
          created_at
          event_type
          object_type
          object_identity
          ddl_command
        ],
      )
      expect(changes.first[:group_name]).to eq(group_name)
      expect(changes.first[:event_type]).to eq("ddl_command_end")
      expect(changes.first[:object_type]).to eq("table")
      expect(changes.first[:object_identity]).to include("sellers")
      expect(changes.first[:ddl_command]).to include("ALTER TABLE")
      expect(changes.first[:ddl_command]).to include("ADD COLUMN email")
    end
  end

  describe ".apply_change" do
    before { described_class.setup(group_name) }

    it "applies ALTER TABLE DDL change to the target database" do
      execute_ddl(
        "ALTER TABLE #{schema_name}.sellers ADD COLUMN email VARCHAR(255)",
      )
      change_id = described_class.list_changes(group_name).first[:id]

      described_class.apply_change(
        connection_url,
        target_connection_url,
        group_name,
        change_id,
      )

      column_exists =
        column_exists?(target_connection_url, schema_name, "sellers", "email")
      expect(column_exists).to be(true)
    end
  end

  describe ".apply_all_changes" do
    before { described_class.setup(group_name) }

    it "applies all DDL changes for the specific group to the target database" do
      execute_ddl(
        "ALTER TABLE #{schema_name}.sellers ADD COLUMN email VARCHAR(255)",
      )
      execute_ddl(
        "ALTER TABLE #{schema_name}.items ADD COLUMN description TEXT",
      )
      execute_ddl(
        "CREATE TABLE #{schema_name}.not_in_group (id serial PRIMARY KEY)",
      ) # This should not be applied

      described_class.apply_all_changes(
        connection_url,
        target_connection_url,
        group_name,
      )

      sellers_column_exists =
        column_exists?(target_connection_url, schema_name, "sellers", "email")
      items_column_exists =
        column_exists?(
          target_connection_url,
          schema_name,
          "items",
          "description",
        )
      not_in_group_exists =
        table_exists_in_schema?(
          target_connection_url,
          schema_name,
          "not_in_group",
        )

      expect(sellers_column_exists).to be(true)
      expect(items_column_exists).to be(true)
      expect(not_in_group_exists).to be(false)
    end
  end
end
