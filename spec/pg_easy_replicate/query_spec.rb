# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Query) do
  describe ".run" do
    before { setup_tables }

    let(:connection_url) do
      "postgres://jamesbond:jamesbond@localhost:5432/postgres"
    end

    it "runs the query successfully" do
      result =
        described_class.run(
          query: "SELECT 'FooBar' as result",
          connection_url: connection_url,
        )

      expect(result).to eq([{ result: "FooBar" }])
    end

    it "sets the statement_timeout" do
      result =
        described_class.run(
          query: "show statement_timeout",
          connection_url: connection_url,
        )

      expect(result).to eq([{ statement_timeout: "5s" }])
    end

    it "performs rollback successfully" do
      query = "ALTER TABLE sellers DROP COLUMN last_login;"
      allow_any_instance_of(Sequel::Postgres::Database).to receive(
        :fetch,
      ).and_raise(PG::DependentObjectsStillExist)

      expect {
        described_class.run(
          query: query,
          connection_url: connection_url,
          schema: "pger_test",
        )
      }.to raise_error(PG::DependentObjectsStillExist)
    end

    it "performs query with supplied schema successfully" do
      expect(
        described_class.run(
          query: "select * from sellers;",
          connection_url: connection_url,
          schema: "pger_test",
        ).to_a,
      ).to eq([])
    end

    it "runs the query successfully with custom user" do
      PgEasyReplicate.bootstrap({ group_name: "cluster1" })

      result =
        described_class.run(
          query: "SELECT session_user, current_user;",
          user: "pger_cluster1",
          connection_url: connection_url,
        )

      expect(result).to eq(
        [{ current_user: "pger_cluster1", session_user: "pger_cluster1" }],
      )

      PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
    end
  end
end
