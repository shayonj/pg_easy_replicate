# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Group) do
  describe ".setup" do
    before do
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
      PgEasyReplicate.setup_internal_schema
    end

    after do
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "creates the table" do
      described_class.setup

      r =
        PgEasyReplicate::Query.run(
          query: "select * from groups",
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(r).to eq([])

      columns_sql = <<~SQL
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = '#{PgEasyReplicate.internal_schema_name}'
        AND table_name = 'groups';
      SQL
      columns =
        PgEasyReplicate::Query.run(
          query: columns_sql,
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
          user: "james-bond",
        )
      expect(columns).to eq(
        [
          { column_name: "id", data_type: "integer" },
          { column_name: "name", data_type: "text" },
          { column_name: "table_names", data_type: "text" },
          { column_name: "schema_name", data_type: "text" },
          {
            column_name: "created_at",
            data_type: "timestamp without time zone",
          },
          {
            column_name: "updated_at",
            data_type: "timestamp without time zone",
          },
          {
            column_name: "started_at",
            data_type: "timestamp without time zone",
          },
          {
            column_name: "failed_at",
            data_type: "timestamp without time zone",
          },
          { column_name: "recreate_indices_post_copy", data_type: "boolean" },
          {
            column_name: "switchover_completed_at",
            data_type: "timestamp without time zone",
          },
        ],
      )
    end
  end

  describe ".drop" do
    before { PgEasyReplicate.bootstrap({ group_name: "cluster1" }) }

    after do
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "drops the table" do
      described_class.setup
      described_class.drop

      sql = <<~SQL
        SELECT EXISTS (
          SELECT FROM
              pg_tables
          WHERE
              schemaname = '#{PgEasyReplicate.internal_schema_name}' AND
              tablename  = 'groups'
          );
      SQL
      r =
        PgEasyReplicate::Query.run(
          query: sql,
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(r).to eq([{ exists: false }])
    end
  end

  describe ".create" do
    before do
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
      described_class.setup
    end

    after do
      described_class.drop
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "adds a row with just the required fields" do
      described_class.create({ name: "test" })

      r =
        PgEasyReplicate::Query.run(
          query: "select * from groups",
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(r.first[:name]).to eq("test")
    end

    it "adds a row with table names and schema" do
      described_class.create(
        { name: "test", table_names: "table1, table2", schema_name: "foo" },
      )

      r =
        PgEasyReplicate::Query.run(
          query: "select * from groups",
          connection_url: connection_url,
          schema: PgEasyReplicate.internal_schema_name,
        )
      expect(r.first[:name]).to eq("test")
      expect(r.first[:table_names]).to eq("table1, table2")
      expect(r.first[:schema_name]).to eq("foo")
    end

    it "captures the error" do
      expect { described_class.create({}) }.to raise_error(
        RuntimeError,
        /Adding group entry failed: PG::NotNullViolation: ERROR:  null value in column "name"/,
      )
    end
  end

  describe ".find" do
    before do
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
      described_class.setup
    end

    after do
      described_class.drop
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "returns a row" do
      described_class.create(
        { name: "test", table_names: "table1, table2", schema_name: "foo" },
      )
      expect(described_class.find("test")).to include(
        switchover_completed_at: nil,
        created_at: kind_of(Time),
        name: "test",
        schema_name: "foo",
        id: kind_of(Integer),
        started_at: nil,
        updated_at: kind_of(Time),
        failed_at: nil,
        table_names: "table1, table2",
      )
    end
  end

  describe ".update" do
    before do
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
      described_class.setup
    end

    after do
      described_class.drop
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "updates the started_at and switchover_completed_at successfully" do
      described_class.create(
        { name: "test", table_names: "table1, table2", schema_name: "foo" },
      )

      described_class.update(
        group_name: "test",
        started_at: Time.now,
        switchover_completed_at: Time.now,
      )

      expect(described_class.find("test")).to include(
        switchover_completed_at: kind_of(Time),
        created_at: kind_of(Time),
        name: "test",
        schema_name: "foo",
        id: kind_of(Integer),
        started_at: kind_of(Time),
        updated_at: kind_of(Time),
        table_names: "table1, table2",
      )
    end
  end

  describe ".delete" do
    before do
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })
      described_class.setup
    end

    after do
      described_class.drop
      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end

    it "returns a row" do
      described_class.create(
        { name: "test", table_names: "table1, table2", schema_name: "foo" },
      )
      described_class.delete("test")

      expect(described_class.find("test")).to be_nil
    end
  end
end
