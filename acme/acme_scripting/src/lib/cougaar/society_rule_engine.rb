$debug_society_model = true

module Cougaar

  module Model

    class RuleEngine
      MAXLOOP = 300
      attr_accessor :max_loop, :society
      
      def initialize(society, max_loop = MAXLOOP)
        @society = society
        @monitor = RuleMonitor.new(society)
        @max_loop = max_loop
        @rules = []
      end
      
      def load_rules(dir)
        rules = Dir.glob(dir+"/**/*.rule")
        rules.each do |rule_file|
          File.open(rule_file) do |file|
            rule = file.read
            instance_eval %Q(
              add_rule('#{rule_file}') do |rule, society|
              #{rule}
              end)
          end
        end
      end
    
      def add_rule(name, proc = nil, &block)
        rule = Rule.new(name, proc, &block)
        @rules << rule
        rule
      end
      
      def execute
        loop = true
        count = 0
        while(loop && count < @max_loop)
          @rules.each do |rule|
            @monitor.current_rule = rule
            puts "Running #{rule.name}"
            rule.execute(@society)
          end
          loop = @monitor.modified?
          count += 1
        end
      end
    end
    
    class Rule
      attr_accessor :name, :description, :fire_count
      
      def initialize(name, proc=nil, &block)
        @name = name
        proc = block unless proc
        @rule = proc
      end
      def execute(society)
        @rule.call(self, society)
      end
    end
    
    class RuleMonitor < SocietyMonitor
      
      attr_accessor :current_rule
      
      def modified?
        return @modified
      end
      
      def clear
        @modified = false
      end
      
      def initialize(society)
        super()
        @society = society
        @modified = false
      end
      def host_added(host)
        @modified = true if host.society == @society
      end
      
      def host_removed(host)
        @modified = true if host.society == @society
      end
      
      def node_added(node)
        @modified = true if node.host.society == @society
      end
      
      def node_removed(node)
        @modified = true if node.host.society == @society
      end
      
      def agent_added(agent)
        @modified = true if agent.node.host.society == @society
      end
      
      def agent_removed(agent)
        @modified = true if agent.node.host.society == @society
      end
      
      def component_added(component)
        @modified = true if component.agent.node.host.society == @society
      end
      
      def component_removed(component)
        @modified = true if component.agent.node.host.society == @society
      end
    end  
  end
end