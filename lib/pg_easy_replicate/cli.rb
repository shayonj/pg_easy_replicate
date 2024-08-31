# frozen_string_literal: true

require "thor"

module PgEasyReplicate
  class CLI < Thor
    package_name "pg_easy_replicate"

    desc "config_check",
         "Prints if source and target database have the required config"
    method_option :special_user_role,
                  aliases: "-s",
                  desc:
                    "Name of the role that has superuser permissions. Usually useful for AWS (rds_superuser) or GCP (cloudsqlsuperuser)."
    method_option :copy_schema,
                  aliases: "-c",
                  boolean: true,
                  desc: "Copy schema to the new database"
    method_option :tables,
                  aliases: "-t",
                  default: "",
                  desc:
                    "Comma separated list of table names. Default: All tables"
    method_option :exclude_tables,
                  aliases: "-e",
                  default: "",
                  desc:
                    "Comma separated list of table names to exclude. Default: None"
    method_option :schema_name,
                  aliases: "-s",
                  desc:
                    "Name of the schema tables are in, only required if passing list of tables"
    def config_check
      PgEasyReplicate.assert_config(
        special_user_role: options[:special_user_role],
        copy_schema: options[:copy_schema],
        tables: options[:tables],
        exclude_tables: options[:exclude_tables],
        schema_name: options[:schema_name],
      )

      puts "✅ Config is looking good."
    end

    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group to provision"
    method_option :special_user_role,
                  aliases: "-s",
                  desc:
                    "Name of the role that has superuser permissions. Usually useful with AWS (rds_superuser) or GCP (cloudsqlsuperuser)."
    method_option :copy_schema,
                  aliases: "-c",
                  boolean: true,
                  desc: "Copy schema to the new database"
    method_option :track_ddl,
                  aliases: "-d",
                  type: :boolean,
                  default: false,
                  desc: "Enable DDL tracking for the group"
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
    method_option :schema_name,
                  aliases: "-s",
                  desc:
                    "Name of the schema tables are in, only required if passing list of tables"
    method_option :tables,
                  aliases: "-t",
                  default: "",
                  desc:
                    "Comma separated list of table names. Default: All tables"
    method_option :exclude_tables,
                  aliases: "-e",
                  default: "",
                  desc:
                    "Comma separated list of table names to exclude. Default: None"
    method_option :recreate_indices_post_copy,
                  type: :boolean,
                  default: false,
                  aliases: "-r",
                  desc:
                    "Drop all non-primary indices before copy and recreate them post-copy"
    method_option :track_ddl,
                  type: :boolean,
                  default: false,
                  desc: "Enable DDL tracking for the group"
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
      PgEasyReplicate::Orchestrate.stop_sync(group_name: options[:group_name])
    end

    desc "switchover",
         "Puts the source database in read only mode after all the data is flushed and written"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group previously provisioned"
    method_option :lag_delta_size,
                  aliases: "-l",
                  desc:
                    "The size of the lag to watch for before switchover. Default 200KB."
    method_option :skip_vacuum_analyze,
                  type: :boolean,
                  default: false,
                  aliases: "-s",
                  desc: "Skip vacuum analyzing tables before switchover."
    def switchover
      PgEasyReplicate::Orchestrate.switchover(
        group_name: options[:group_name],
        lag_delta_size: options[:lag_delta_size],
        skip_vacuum_analyze: options[:skip_vacuum_analyze],
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

    desc "list_ddl_changes", "Lists recent DDL changes in the source database"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group"
    method_option :limit,
                  aliases: "-l",
                  type: :numeric,
                  default: 100,
                  desc: "Limit the number of DDL changes to display"
    def list_ddl_changes
      changes =
        PgEasyReplicate::DDLManager.list_ddl_changes(
          group_name: options[:group_name],
          limit: options[:limit],
        )
      puts JSON.pretty_generate(changes)
    end

    desc "apply_ddl_change", "Applies DDL changes to the target database"
    method_option :group_name,
                  aliases: "-g",
                  required: true,
                  desc: "Name of the group"
    method_option :id,
                  aliases: "-i",
                  type: :numeric,
                  desc:
                    "ID of the specific DDL change to apply. If not provided, all changes will be applied."
    def apply_ddl_change
      if options[:id]
        PgEasyReplicate::DDLManager.apply_ddl_change(
          group_name: options[:group_name],
          id: options[:id],
        )
        puts "DDL change with ID #{options[:id]} applied successfully."
      else
        changes =
          PgEasyReplicate::DDLManager.list_ddl_changes(
            group_name: options[:group_name],
          )
        if changes.empty?
          puts "No pending DDL changes to apply."
          return
        end

        puts "The following DDL changes will be applied:"
        changes.each do |change|
          puts "ID: #{change[:id]}, Type: #{change[:object_type]}, Command: #{change[:ddl_command]}"
        end
        puts ""
        print("Do you want to apply all these changes? (y/n): ")
        confirmation = $stdin.gets.chomp.downcase

        if confirmation == "y"
          PgEasyReplicate::DDLManager.apply_all_ddl_changes(
            group_name: options[:group_name],
          )
          puts "All pending DDL changes applied successfully."
        else
          puts "Operation cancelled."
        end
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
