# frozen_string_literal: true

module PgEasyReplicate
  class Stats
    extend Helper

    class << self
      def print(group_name)
        # print stats
      end

      def follow(group_name)
        loop do
          print(group_name)
          sleep(1)
        end
      end
    end
  end
end
