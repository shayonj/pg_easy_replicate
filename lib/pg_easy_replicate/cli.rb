# frozen_string_literal: true

require "thor"

module PgEasyReplicate
  class CLI < Thor
    package_name "pg_easy_replicate"

    desc "config_check",
         "Prints if source and target database have the required config"
    def config_check
      PgEasyReplicate.assert_config

      puts "✅ Config is looking good."
    end

    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group to provision"
    desc "bootstrap",
         "Sets up temporary tables for information required during runtime"
    def bootstrap
      PgEasyReplicate.bootstrap(options)
    end

    desc "cleanup", "Cleans up all bootstrapped data for the respective group"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group previously provisioned"
    method_option :everything,
                  aliases: "-e",
                  desc:
                    "Cleans up all bootstrap tables, users and any publication/subscription"
    method_option :sync,
                  aliases: "-s",
                  desc:
                    "Cleans up the publication and subscription for the respective group"
    def cleanup
      PgEasyReplicate.cleanup(options)
    end

    desc "start_sync",
         "Starts the logical replication from source database to target database provisioned in the group"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group to provision"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc:
                    "Name of the grouping for this collection of source and target DB"
    method_option :schema_name,
                  aliases: "-s",
                  desc:
                    "Name of the schema tables are in, only required if passing list of tables"
    method_option :tables,
                  aliases: "-t",
                  desc:
                    "Comma separated list of table names. Default: All tables"
    def start_sync
      PgEasyReplicate::Orchestrate.start_sync(options)
    end

    desc "stop_sync",
         "Stop the logical replication from source database to target database provisioned in the group"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group previously provisioned"
    def stop_sync
      PgEasyReplicate::Orchestrate.stop_sync(options[:group_name])
    end

    desc "switchover ",
         "Puts the source database in read only mode after all the data is flushed and written"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group previously provisioned"
    method_option :lag_delta_size,
                  aliases: "-l",
                  desc:
                    "The size of the lag to watch for before switchover. Default 200KB."
    # method_option :bi_directional,
    #               aliases: "-b",
    #               desc:
    #                 "Setup replication from target database to source database"
    def switchover
      PgEasyReplicate::Orchestrate.switchover(
        group_name: options[:group_name],
        lag_delta_size: options[:lag_delta_size],
      )
    end

    desc "stats ", "Prints the statistics in JSON for the group"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group previously provisioned"
    method_option :watch, aliases: "-w", desc: "Tail the stats"
    def stats
      if options[:watch]
        PgEasyReplicate::Stats.follow(options[:group_name])
      else
        PgEasyReplicate::Stats.print(options[:group_name])
      end
    end

    desc "version", "Prints the version"
    def version
      puts PgEasyReplicate::VERSION
    end

    def self.exit_on_failure?
      true
    end
  end
end
