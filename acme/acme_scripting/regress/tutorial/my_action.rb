module Cougaar
  module Actions
    class MyFirstAction < Cougaar::Action
      RESULTANT_STATE = "MyFirstActionWasRun"
      def initialize(run, name)
        super(run)
        @name = name
      end
      def perform
        puts "#{@name} is cool"
      end
    end
  end

  #Define MyFirstActionWasRun State

  module States
    class MyFirstActionWasRun < Cougaar::NOOPState
    end
  end
end

