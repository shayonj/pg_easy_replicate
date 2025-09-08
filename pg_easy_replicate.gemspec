# frozen_string_literal: true

require_relative "lib/pg_easy_replicate/version"

Gem::Specification.new do |spec|
  spec.name = "pg_easy_replicate"
  spec.version = PgEasyReplicate::VERSION
  spec.authors = ["Shayon Mukherjee"]
  spec.email = ["shayonj@gmail.com"]

  spec.description =
    "Easily setup logical replication and switchover to new database with minimal downtime"
  spec.summary = spec.description
  spec.homepage = "https://github.com/shayonj/pg_easy_replicate"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata[
    "changelog_uri"
  ] = "https://github.com/shayonj/pg_easy_replicate/blob/main/CODE_OF_CONDUCT.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(File.expand_path(__dir__)) do
      `git ls-files -z`.split("\x0")
        .reject do |f|
          (f == __FILE__) ||
            f.match(
              %r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)},
            )
        end
    end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata = { "rubygems_mfa_required" => "true" }

  spec.add_dependency("ougai", "~> 2.0.0")
  spec.add_dependency("pg", "~> 1.5.3")
  spec.add_dependency("pg_query", "~> 5.1.0")
  spec.add_dependency("sequel", ">= 5.69", "< 5.97")
  spec.add_dependency("thor", ">= 1.2.2", "< 1.4.0")

  # rubocop:disable Gemspec/DevelopmentDependencies
  spec.add_development_dependency("prettier_print")
  spec.add_development_dependency("pry")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("rspec")
  spec.add_development_dependency("rubocop")
  spec.add_development_dependency("rubocop-packaging")
  spec.add_development_dependency("rubocop-performance")
  spec.add_development_dependency("rubocop-rake")
  spec.add_development_dependency("rubocop-rspec")
  spec.add_development_dependency("syntax_tree")
  spec.add_development_dependency("syntax_tree-haml")
  spec.add_development_dependency("syntax_tree-rbs")
  # rubocop:enable Gemspec/DevelopmentDependencies
end
