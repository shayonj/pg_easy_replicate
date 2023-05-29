# frozen_string_literal: true

module PgEasyReplicate
  class Orchestrate
    extend Helper

    class << self
      def start_sync
        # assert prelimnary checks
      end

      def stop_sync
        # assert prelimnary checks
        # assert subscription publication is setup
      end

      def switchover
        # assert prelimnary checks
        # assert subscription publication is setup
      end
    end
  end
end
