# frozen_string_literal: true

RSpec.describe("SmokeSpec") do
  describe "dataset" do
    it "matches after switchover" do
      # Bootstrap
      `./scripts/e2e-bootstrap.sh`

      r =
        PgEasyReplicate::Query.run(
          query: "select count(*) from pgbench_accounts",
          connection_url: connection_url,
          user: "jamesbond",
        )
      expect(r).to eq([{ count: 500_000 }])
      last_count = r.last[:count]

      pid =
        fork do
          puts("Running insertions")
          100.times do |i|
            new_aid = last_count + (i + 1)
            sql = <<~SQL
              INSERT INTO "public"."pgbench_accounts"("aid", "bid", "abalance", "filler") VALUES(#{new_aid}, 1, 0, '0') RETURNING "aid", "bid", "abalance", "filler";
            SQL
            PgEasyReplicate::Query.run(
              query: sql,
              connection_url: connection_url,
              user: "jamesbond",
            )
          end
        end
      Process.wait(pid)

      # Start sync and switch over
      # Its possible there are no writes happening while the swithover,
      # which is OK otherwise the forked process will just keep looking on trying to insert
      # in a read only connection. We can look into parralelizing writes in future.

      `./scripts/e2e-start.sh`

      r =
        PgEasyReplicate::Query.run(
          query: "select count(*) from pgbench_accounts",
          connection_url: target_connection_url,
          user: "jamesbond",
        )
      expect(r).to eq([{ count: 500_100 }])
    ensure
      begin
        Process.kill("KILL", pid) if pid
      rescue Errno::ESRCH
        puts("proc closed")
      end
    end
  end
end
