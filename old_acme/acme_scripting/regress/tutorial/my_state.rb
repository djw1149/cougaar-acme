module Cougaar
  module States
    class MyFirstState < Cougaar::State
      PRIOR_STATES = ["MyFirstActionWasRun"]
      DEFAULT_TIMEOUT = 15.seconds
      def process
        sleep 10
        raise "suckage"
        puts "States are fun!"
      end
      def unhandled_timeout
        puts "timeout not handled"
      end
    end
  end
end

