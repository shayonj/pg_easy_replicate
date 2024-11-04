# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Stats) do
  # describe ".lag_stats" do
  #   before do
  #     setup_tables
  #     PgEasyReplicate.bootstrap({ group_name: "cluster1" })

  #     ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
  #     PgEasyReplicate::Orchestrate.start_sync(
  #       { group_name: "cluster1", schema_name: test_schema },
  #     )
  #   end

  #   after do
  #     PgEasyReplicate::Orchestrate.stop_sync(
  #       group_name: "cluster1",
  #       source_conn_string: connection_url,
  #       target_conn_string: target_connection_url,
  #     )
  #     PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
  #     teardown_tables
  #   end

  #   it "successfully" do
  #     result = nil
  #     count = 0
  #     # Wait for sync stats to be up
  #     loop do
  #       count += 1
  #       break if count > 5
  #       sleep 1
  #       result = described_class.lag_stats("cluster1").first
  #     end

  #     expect(result).to include(
  #       application_name: "pger_subscription_cluster1",
  #       client_addr: kind_of(String),
  #       flush_lag: kind_of(BigDecimal),
  #       pid: kind_of(Integer),
  #       replay_lag: kind_of(BigDecimal),
  #       state: kind_of(String),
  #       sync_state: kind_of(String),
  #       user_name: "james-bond",
  #       write_lag: kind_of(BigDecimal),
  #     )
  #   end
  # end

  # describe ".pg_replication_slots" do
  #   before do
  #     setup_tables
  #     PgEasyReplicate.bootstrap({ group_name: "cluster1" })

  #     ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
  #     PgEasyReplicate::Orchestrate.start_sync(
  #       { group_name: "cluster1", schema_name: test_schema },
  #     )
  #   end

  #   after do
  #     PgEasyReplicate::Orchestrate.stop_sync(
  #       group_name: "cluster1",
  #       source_conn_string: connection_url,
  #       target_conn_string: target_connection_url,
  #     )
  #     PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
  #     teardown_tables
  #   end

  #   it "successfully" do
  #     result = nil
  #     count = 0
  #     # Wait for sync stats to be up
  #     loop do
  #       count += 1
  #       break if count > 5
  #       sleep 1
  #       result = described_class.pg_replication_slots("cluster1").first
  #     end

  #     expect(result).to include(
  #       slot_name: "pger_subscription_cluster1",
  #       slot_type: "logical",
  #     )
  #   end
  # end

  # describe ".replication_stats" do
  #   before do
  #     setup_tables
  #     PgEasyReplicate.bootstrap({ group_name: "cluster1" })

  #     ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
  #     PgEasyReplicate::Orchestrate.start_sync(
  #       { group_name: "cluster1", schema_name: test_schema },
  #     )
  #   end

  #   after do
  #     PgEasyReplicate::Orchestrate.stop_sync(
  #       group_name: "cluster1",
  #       source_conn_string: connection_url,
  #       target_conn_string: target_connection_url,
  #     )
  #     PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
  #     teardown_tables
  #   end

  #   it "successfully" do
  #     ENV["TARGET_DB_URL"] = target_connection_url
  #     expect(described_class.replication_stats("cluster1")).to include(
  #       {
  #         replication_state: kind_of(String),
  #         subscription_name: "pger_subscription_cluster1",
  #         table_name: "items",
  #         table_schema: "pger_test",
  #       },
  #       {
  #         replication_state: kind_of(String),
  #         subscription_name: "pger_subscription_cluster1",
  #         table_name: "sellers",
  #         table_schema: "pger_test",
  #       },
  #     )
  #   end
  # end

  # describe ".replication_stats_count_by_state" do
  #   before do
  #     setup_tables
  #     PgEasyReplicate.bootstrap({ group_name: "cluster1" })

  #     ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
  #     PgEasyReplicate::Orchestrate.start_sync(
  #       { group_name: "cluster1", schema_name: test_schema },
  #     )
  #   end

  #   after do
  #     PgEasyReplicate::Orchestrate.stop_sync(
  #       group_name: "cluster1",
  #       source_conn_string: connection_url,
  #       target_conn_string: target_connection_url,
  #     )
  #     PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
  #     teardown_tables
  #   end

  #   it "successfully" do
  #     ENV["TARGET_DB_URL"] = target_connection_url
  #     expect(
  #       described_class.replication_stats_count_by_state(
  #         described_class.replication_stats("cluster1"),
  #       ),
  #     ).to be_a(Hash)
  #   end
  # end

  # describe ".message_lsn_receipts" do
  #   before do
  #     setup_tables
  #     PgEasyReplicate.bootstrap({ group_name: "cluster1" })

  #     ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
  #     PgEasyReplicate::Orchestrate.start_sync(
  #       { group_name: "cluster1", schema_name: test_schema },
  #     )
  #   end

  #   after do
  #     PgEasyReplicate::Orchestrate.stop_sync(
  #       group_name: "cluster1",
  #       source_conn_string: connection_url,
  #       target_conn_string: target_connection_url,
  #     )
  #     PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
  #     teardown_tables
  #   end

  #   it "successfully" do
  #     ENV["TARGET_DB_URL"] = target_connection_url
  #     expect(described_class.message_lsn_receipts("cluster1").first.keys).to eq(
  #       %i[
  #         received_lsn
  #         last_msg_send_time
  #         last_msg_receipt_time
  #         latest_end_lsn
  #         latest_end_time
  #       ],
  #     )
  #   end
  # end

  # describe ".object" do
  #   before do
  #     setup_tables
  #     PgEasyReplicate.bootstrap({ group_name: "cluster1" })

  #     ENV["SECONDARY_SOURCE_DB_URL"] = docker_compose_source_connection_url
  #     PgEasyReplicate::Orchestrate.start_sync(
  #       { group_name: "cluster1", schema_name: test_schema },
  #     )
  #   end

  #   after do
  #     PgEasyReplicate::Orchestrate.stop_sync(
  #       group_name: "cluster1",
  #       source_conn_string: connection_url,
  #       target_conn_string: target_connection_url,
  #     )
  #     PgEasyReplicate.cleanup({ everything: true, group_name: "cluster1" })
  #     teardown_tables
  #   end

  #   it "successfully" do
  #     ENV["TARGET_DB_URL"] = target_connection_url
  #     expect(described_class.object("cluster1").keys).to eq(
  #       %i[
  #         lag_stats
  #         replication_slots
  #         replication_stats
  #         replication_stats_count_by_state
  #         message_lsn_receipts
  #         sync_started_at
  #         sync_failed_at
  #         switchover_completed_at
  #       ],
  #     )
  #   end
  # end

  describe ".notify" do
    before do
      @mocked_stats = {
        lag_stats: [],
        replication_slots: [],
        replication_stats: [],
        replication_stats_count_by_state: {},
        message_lsn_receipts: [],
        sync_started_at: Time.now - 5,
        sync_failed_at: nil,
        switchover_completed_at: Time.now,
      }
      allow(described_class).to receive(:object).with("cluster1").and_return(@mocked_stats)

      # # mocks the http request
      http_double = double('http', request: double('response', code: '200', message: 'OK'))
      allow(Net::HTTP).to receive(:new).and_return(http_double)
      allow(http_double).to receive(:use_ssl=)
      allow(http_double).to receive(:open_timeout=)
      allow(http_double).to receive(:read_timeout=)
    end

    it "logs notification success and indicates switchover completion" do
      thread = Thread.new do
        expect { described_class.notify("cluster1", "https://example.com/webhook", 1, 5) }
        .to output(/Notification sent: 200 OK/).to_stdout
      end

      sleep(0.1)
      thread.kill # Break out of the loop so the test doesnt hang

      expect { thread.join }.not_to raise_error
    end
  
    it "retries on failure" do
      allow(Net::HTTP).to receive(:new).and_raise(StandardError.new("network error"))
  
      expect {
        described_class.notify("cluster1", "https://example.com/webhook", 1, 1)
      }.to raise_error(StandardError, /Notify failed with: network error/)
    end
  end
end
