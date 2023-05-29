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
  end
end
