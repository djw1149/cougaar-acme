module Cougaar
  module States
    class MyFirstState < Cougaar::State
      PRIOR_STATES = ["MyFirstActionWasRun"]
      DEFAULT_TIMEOUT = 5.seconds
      def process
        sleep 7
        puts "States are fun!"
      end
      def unhandled_timeout
        puts "hello"
      end
    end
  end
end

