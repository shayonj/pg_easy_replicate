# frozen_string_literal: true

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
        )
      expect(r).to eq([{ count: 500_000 }])
      last_count = r.last[:count]

      pid =
        fork do
          puts("Running insertions")
          3000.times do |i|
            new_aid = last_count + (i + 1)
            sql = <<~SQL
            INSERT INTO "public"."pgbench_accounts"("aid", "bid", "abalance", "filler") VALUES(#{new_aid}, 1, 0, '0') RETURNING "aid", "bid", "abalance", "filler";
          SQL
            PgEasyReplicate::Query.run(
              query: sql,
              connection_url: connection_url,
              user: "james-bond",
            )
          rescue => e
            if e.message.include?(
                 "cannot execute INSERT in a read-only transaction",
               ) || e.message.include?("terminating connection")
              PgEasyReplicate::Query.run(
                query: sql,
                connection_url: target_connection_url,
                user: "james-bond",
              )
            else
              raise
            end
          end
        end
      Process.detach(pid)

      system("./scripts/e2e-start.sh")
      expect($CHILD_STATUS.success?).to be(true)

      begin
        Process.wait(pid)
      rescue Errno::ECHILD #rubocop:disable Lint/SuppressedException
      end

      r =
        PgEasyReplicate::Query.run(
          query: "select count(*) from pgbench_accounts",
          connection_url: target_connection_url,
          user: "james-bond",
        )
      expect(r).to eq([{ count: 503_000 }])

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
    ensure
      begin
        Process.kill("KILL", pid) if pid
      rescue Errno::ESRCH
        puts("proc closed")
      end
    end
  end
end
