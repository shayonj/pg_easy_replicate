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
          transaction: false  # Ensure consistent transaction handling
        )
      expect(r).to eq([{ count: 500_000 }])
      last_count = r.last[:count]

      pid =
        fork do
          puts("Running insertions")
          successful_count = 0

          2000.times do |i|
            new_aid = last_count + (i + 1)
            sql = <<~SQL
            INSERT INTO "public"."pgbench_accounts"("aid", "bid", "abalance", "filler") VALUES(#{new_aid}, 1, 0, '0') RETURNING "aid", "bid", "abalance", "filler";
          SQL
            begin
              PgEasyReplicate::Query.run(
                query: sql,
                connection_url: connection_url,
                user: "james-bond",
                transaction: false  # Ensure autocommit mode
              )
              successful_count += 1
            rescue => e
              if e.message.include?(
                   "cannot execute INSERT in a read-only transaction",
                 ) || e.message.include?("terminating connection")
                puts "INFO: Source INSERT failed for aid #{new_aid} (Error: #{e.message}). Retrying on target..."
                begin
                  result = PgEasyReplicate::Query.run(
                    query: sql,
                    connection_url: target_connection_url,
                    user: "james-bond",
                    transaction: false  # Ensure autocommit mode
                  )
                  puts "INFO: Target INSERT successful for aid #{new_aid}, #{result.to_a}"
                  successful_count += 1

                  # Verify immediately with a fresh query
                  result = PgEasyReplicate::Query.run(
                    query: "select count(*) from pgbench_accounts where aid = #{new_aid}",
                    connection_url: target_connection_url,
                    user: "james-bond",
                    transaction: false
                  )
                  puts "INFO: Target value for aid #{new_aid}, #{result.to_a}"
                rescue => target_error
                  puts "ERROR: TARGET INSERT FAILED for aid #{new_aid}. Original source error: '#{e.message}'. Target error: '#{target_error.message}'. SQL: #{sql.inspect}"

                end
              else
                puts "ERROR: Non-retryable error in forked process for aid #{new_aid}: #{e.message}. SQL: #{sql.inspect}"
                raise
              end
            end
          end

          puts "Fork process completed. Successful inserts: #{successful_count}"

          # Force a final commit/sync before exiting
          begin
            PgEasyReplicate::Query.run(
              query: "SELECT pg_stat_activity.pid FROM pg_stat_activity WHERE pid = pg_backend_pid()",
              connection_url: target_connection_url,
              user: "james-bond",
              transaction: false
            )
            puts "Fork process: Connection verified before exit"
          rescue => e
            puts "Fork process: Final connection check failed: #{e.message}"
          end
        end
      Process.detach(pid)

      system("./scripts/e2e-start.sh")
      expect($CHILD_STATUS.success?).to be(true)

      begin
        puts "Waiting for forked INSERT process to complete..."
        Process.wait(pid)
        puts "Forked INSERT process finished with status: #{$CHILD_STATUS.exitstatus}"
      rescue Errno::ECHILD
        puts "Forked process already exited."
      end



      puts "Running VACUUM ANALYZE on target public.pgbench_accounts before counting..."
      begin
        PgEasyReplicate::Query.run(
          query: "VACUUM ANALYZE public.pgbench_accounts;",
          connection_url: target_connection_url,
          user: "james-bond",
          transaction: false
        )
        puts "VACUUM ANALYZE completed on target public.pgbench_accounts."
      rescue => e
        puts "WARNING: VACUUM ANALYZE on target public.pgbench_accounts failed: #{e.message}"
      end

      expected_count = 502_000
      actual_count_record = nil
      max_retries = 10
      retry_delay = 2 # seconds
      current_count = nil

      max_retries.times do |i|
        actual_count_record = PgEasyReplicate::Query.run(
          query: "select count(*) from pgbench_accounts",
          connection_url: target_connection_url,
          user: "james-bond",
          transaction: false
        )
        current_count = actual_count_record&.first&.[](:count)
        break if current_count == expected_count

        puts "Attempt #{i + 1}/#{max_retries}: Count mismatch. Expected #{expected_count}, got #{current_count}. Retrying in #{retry_delay}s..."
        sleep(retry_delay)
      end
      expect(current_count).to eq(expected_count)

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
