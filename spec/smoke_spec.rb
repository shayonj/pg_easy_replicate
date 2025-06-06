# frozen_string_literal: true

require 'English'
RSpec.describe("SmokeSpec") do
  describe "dataset" do
    it "matches after switchover and applies DDL changes" do
      # Bootstrap
      system("./scripts/e2e-bootstrap.sh")
      expect($CHILD_STATUS.success?).to be(true)

      r =
        PgEasyReplicate::Query.run(
          query: "select count(*) from pgbench_accounts",
          connection_url: connection_url,
          user: "james-bond",
          transaction: false
        )
      expect(r).to eq([{ count: 500_000 }])
      last_count = r.last[:count]

      # Do inserts in batches with switchover in the middle
      puts "Phase 1: Inserting first 1000 records on source..."
      1000.times do |i|
        new_aid = last_count + (i + 1)
        insert_record(new_aid, connection_url)
      end

      puts "Phase 2: Starting switchover..."
      system("./scripts/e2e-start.sh")
      expect($CHILD_STATUS.success?).to be(true)

      puts "Phase 3: Inserting remaining 1000 records (will retry on target after switchover)..."
      1000.times do |i|
        new_aid = last_count + 1000 + (i + 1)
        insert_with_retry(new_aid)
      end

      puts "Phase 4: Verifying final count..."
      # Simple verification with retries
      expected_count = 502_000
      current_count = nil

      5.times do |attempt|
        result = PgEasyReplicate::Query.run(
          query: "select count(*) from pgbench_accounts",
          connection_url: target_connection_url,
          user: "james-bond",
          transaction: false
        )
        current_count = result&.first&.[](:count)

        puts "Attempt #{attempt + 1}: Count = #{current_count} (expected #{expected_count})"
        break if current_count == expected_count

        sleep(2)
      end

      expect(current_count).to eq(expected_count)

      # Verify DDL changes
      columns =
        PgEasyReplicate::Query.run(
          query:
            "SELECT column_name FROM information_schema.columns WHERE table_name = 'pgbench_accounts' AND column_name = 'test_column'",
          connection_url: target_connection_url,
          user: "james-bond",
        )
      expect(columns).to eq([{ column_name: "test_column" }])

      expect(
        vacuum_stats(url: target_connection_url, schema: "public"),
      ).to include(
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "pgbench_tellers",
        },
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "pgbench_history",
        },
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "pgbench_branches",
        },
        {
          last_analyze: kind_of(Time),
          last_vacuum: kind_of(Time),
          relname: "pgbench_accounts",
        },
      )
    end

    private

    def insert_record(aid, conn_url)
      sql = <<~SQL
        INSERT INTO "public"."pgbench_accounts"("aid", "bid", "abalance", "filler")
        VALUES(#{aid}, 1, 0, '0') RETURNING "aid", "bid", "abalance", "filler";
      SQL

      PgEasyReplicate::Query.run(
        query: sql,
        connection_url: conn_url,
        user: "james-bond",
        transaction: false
      )
    end

    def insert_with_retry(aid)
      sql = <<~SQL
        INSERT INTO "public"."pgbench_accounts"("aid", "bid", "abalance", "filler")
        VALUES(#{aid}, 1, 0, '0') RETURNING "aid", "bid", "abalance", "filler";
      SQL

      begin
        # Try source first
        PgEasyReplicate::Query.run(
          query: sql,
          connection_url: connection_url,
          user: "james-bond",
          transaction: false
        )
      rescue => e
        if e.message.include?("cannot execute INSERT in a read-only transaction") ||
           e.message.include?("terminating connection")
          # Source is read-only, retry on target
          PgEasyReplicate::Query.run(
            query: sql,
            connection_url: target_connection_url,
            user: "james-bond",
            transaction: false
          )
        else
          raise
        end
      end
    end
  end
end
