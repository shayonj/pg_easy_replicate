# frozen_string_literal: true

require "pg_easy_replicate"
require "./spec/database_helpers"
require "pry"

ENV["RACK_ENV"] = "test"
ENV["DEBUG"] = "true"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with(:rspec) { |c| c.syntax = :expect }

  config.include(DatabaseHelpers)
  config.before(:suite) { DatabaseHelpers.populate_env_vars }
  config.after(:suite) do
    PgEasyReplicate.drop_schema
  rescue StandardError # rubocop:disable Lint/SuppressedException
  end
end
