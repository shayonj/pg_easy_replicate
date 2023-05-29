# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Query) do
  describe ".run" do
    before { setup_tables }

    let(:connection_url) do
      "postgres://jamesbond:jamesbond@localhost:5432/postgres"
    end

    it "runs the query successfully" do
      expect_any_instance_of(PG::Connection).to receive(:async_exec).with(
        "BEGIN;",
      ).and_call_original
      expect_any_instance_of(PG::Connection).to receive(:async_exec).with(
        "SELECT 'FooBar' as result",
      ).and_call_original
      expect_any_instance_of(PG::Connection).to receive(:async_exec).with(
        "COMMIT;",
      ).and_call_original

      result =
        described_class.run(
          query: "SELECT 'FooBar' as result",
          connection_url: connection_url,
        )

      expect(result).to eq([{ "result" => "FooBar" }])
    end

    it "performs rollback successfully" do
      query = "ALTER TABLE sellers DROP COLUMN last_login;"
      expect_any_instance_of(PG::Connection).to receive(:async_exec).with(
        "BEGIN;",
      ).and_call_original
      expect_any_instance_of(PG::Connection).to receive(:async_exec).with(
        "ROLLBACK;",
      ).and_call_original
      expect_any_instance_of(PG::Connection).to receive(:async_exec).with(
        "COMMIT;",
      ).and_call_original
      allow_any_instance_of(PG::Connection).to receive(:async_exec).with(
        query,
      ).and_raise(PG::DependentObjectsStillExist)

      expect {
        described_class.run(query: query, connection_url: connection_url)
      }.to raise_error(PG::DependentObjectsStillExist)
    end
  end
end
