$debug_society_model = true

module Cougaar

  module Model

    class RuleEngine
      MAXLOOP = 300
      attr_accessor :max_loop, :society
      attr_reader :monitor
      
      def initialize(society, max_loop = MAXLOOP)
        @society = society
        @monitor = RuleMonitor.new(society)
        @max_loop = max_loop
        @rules = []
        @stdout_enabled = false
      end
      
      def enable_stdout
        @stdout_enabled = true
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
          @monitor.clear
          @rules.each do |rule|
            @monitor.current_rule = rule
            puts "Executing rule: #{rule.name}." if @stdout_enabled
            rule.execute(@society)
            @monitor.report if @stdout_enabled
            @monitor.clear_counters if @stdout_enabled
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
        clear_counters
      end
      
      def clear_counters
        @hosts_added = @hosts_removed = 0
        @nodes_added = @nodes_removed = 0
        @agents_added = @agents_removed = 0
        @components_added = @components_removed = 0
      end
      
      def initialize(society)
        super()
        @society = society
        clear
      end
      def host_added(host)
        @modified = true if host.society == @society
        @hosts_added += 1
      end
      
      def host_removed(host)
        @modified = true if host.society == @society
        @hosts_removed += 1
      end
      
      def node_added(node)
        @modified = true if node.host.society == @society
        @nodes_added += 1
      end
      
      def node_removed(node)
        @modified = true if node.host.society == @society
        @nodes_removed += 1
      end
      
      def agent_added(agent)
        @modified = true if agent.node.host.society == @society
        @agents_added += 1
      end
      
      def agent_removed(agent)
        @modified = true if agent.node.host.society == @society
        @agents_removed += 1
      end
      
      def component_added(component)
        @modified = true if component.agent.node.host.society == @society
        @components_added += 1
      end
      
      def component_removed(component)
        @modified = true if component.agent.node.host.society == @society
        @components_removed += 1
      end
      
      def report
        puts "Added #{@hosts_added} hosts."  if @hosts_added > 0
        puts "Removed #{@hosts_removed} hosts."  if @hosts_removed > 0
        puts "Added #{@nodes_added} nodes."  if @nodes_added > 0
        puts "Removed #{@nodes_removed} nodes."  if @nodes_removed > 0
        puts "Added #{@agents_added} agents."  if @agents_added > 0
        puts "Removed #{@agents_removed} agents."  if @agents_removed > 0
        puts "Added #{@components_added} components."  if @components_added > 0
        puts "Removed #{@components_removed} components."  if @components_removed > 0
      end
    end  
  end
end