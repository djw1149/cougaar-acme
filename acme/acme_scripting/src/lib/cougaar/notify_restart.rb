module Cougaar
  module Actions
    class NotifyRestart <  Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Load a society from a persistence snapshot file."
        @parameters = [
          {:filename => "required, The persistence snapshot filename"},
          {:debug => "boolean=false, True to print out debug messages"}
        ]
        @example = "do_action 'LoadSocietyFromPersistenceSnapshot', '~/snapshot.tgz''"
      }

      def initialize(run)
        super(run)
      end

      def perform()
        @run.society.each_node do |node|
          node.replace_parameter(/Dorg.cougaar.tools.robustness.deconfliction.leashOnRestart/, 
				"-Dorg.cougaar.tools.robustness.deconfliction.leashOnRestart=true")
        end
      end
      
    end
  end
end
