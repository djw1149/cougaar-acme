module Cougaar
  module Actions
  
    class MyFirstAction < Cougaar::Action
      RESULTANT_STATE = "MyFirstActionWasRun"
      def initialize(run, name)
        super(run)
        @name = name
      end
      def perform
        @run.info_message "MyFirstAction: #{@name}"
        @run.add_to_interrupt_stack do 
          do_action "MyFirstAction", "foobar"
        end
      end
    end
    
    class MySecondAction < Cougaar::Action
      def initialize(run, name)
        super(run)
        @name = name
      end
      def perform
        @run.info_message "MySecondAction: #{@name}"
        #sleep 5
        raise "This is an exception"
      end
    end
  end

  #Define MyFirstActionWasRun State

  module States
    class MyFirstActionWasRun < Cougaar::NOOPState
    end
  end
end

