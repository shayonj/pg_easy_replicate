# frozen_string_literal: true

module PgEasyReplicate
  module Helper
    def source_db_url
      ENV.fetch("SOURCE_DB_URL", nil)
    end

    def target_db_url
      ENV.fetch("TARGET_DB_URL", nil)
    end

    def logger
      PgEasyReplicate.logger
    end

    def internal_schema_name
      "pger"
    end

    def test_env?
      ENV.fetch("RACK_ENV", nil) == "test"
    end

    def abort_with(msg)
      raise(msg) if test_env?
      abort(msg)
    end
  end
end
