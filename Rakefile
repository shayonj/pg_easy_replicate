# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "standalone_migrations"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: [:spec, :rubocop]
