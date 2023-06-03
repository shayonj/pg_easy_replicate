# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Group) do
  before { described_class.drop }

  describe ".setup" do
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
        )
      expect(columns).to eq(
        [
          { "column_name" => "id", "data_type" => "integer" },
          { "column_name" => "source_db_connstring", "data_type" => "text" },
          { "column_name" => "target_db_connstring", "data_type" => "text" },
          {
            "column_name" => "encryption_key",
            "data_type" => "character varying",
          },
          { "column_name" => "name", "data_type" => "text" },
          { "column_name" => "table_names", "data_type" => "text" },
          { "column_name" => "schema_name", "data_type" => "text" },
          {
            "column_name" => "created_at",
            "data_type" => "timestamp without time zone",
          },
          {
            "column_name" => "started_at",
            "data_type" => "timestamp without time zone",
          },
          {
            "column_name" => "completed_at",
            "data_type" => "timestamp without time zone",
          },
        ],
      )
    end
  end

  describe ".drop" do
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
      expect(r).to eq([{ "exists" => "f" }])
    end
  end
end
