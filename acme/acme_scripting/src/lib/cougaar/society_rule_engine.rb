$debug_society_model = true

module Cougaar

  module Model

    class RuleEngine
      MAXLOOP = 300
      attr_accessor :max_loop, :society, :abort_on_warning
      attr_reader :monitor
      
      def initialize(society, max_loop = MAXLOOP)
        @society = society
        @monitor = RuleMonitor.new(society)
        @max_loop = max_loop
        @rules = []
        @stdout_enabled = false
        @abort_on_warning = false
      end
      
      def enable_stdout
        @stdout_enabled = true
      end
      
      def load_rules(list)
        list.split(":").each do |item|
          raise "Unknown file or direcotory: #{item}" unless File.exist?(item)
          if File.stat(item).directory?
            rules = Dir.glob(File.join(item, "*.rule"))
          else
            rules = [item]
          end
          rules.each do |rule_file|
            File.open(rule_file) do |file|
              rule = file.read
              begin
                instance_eval %Q(
                  add_rule('#{rule_file}') do |rule, society|
                  #{rule}
                  end)
              rescue Exception => error
                output_warning "Error loading rule #{rule_file}: #{error}\n#{error.backtrace.join("\n")}"
              end
            end
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
            rule.execute(self, @society)
            @monitor.report if @stdout_enabled
            @monitor.clear_counters if @stdout_enabled
          end
          loop = @monitor.modified?
          count += 1
        end
        if count >= @max_loop
          output_warning "Detected endless loop in rule applciation."
        end
        unused_rules = []
        @rules.each do |rule|
          unused_rules << rule.name unless rule.modified_society?
        end
        if unused_rules.size > 0
          output_warning "The rule(s)s: #{unused_rules.join(', ')} did not modify the society."
        end
        @monitor.finish
      end
      
      def output_warning(message)
        message = "Rule Engine Warning: #{message}"
        if abort_on_warning
          raise "\n#{message}"
        else
          puts message
        end
      end
    end
    
    class Rule
      attr_accessor :name, :description, :fire_count, :modified_society
      
      def initialize(name, proc=nil, &block)
        @name = name
        proc = block unless proc
        @rule = proc
        @modified_society = false
      end
      
      def modified_society?
        @modified_society
      end
      
      def execute(engine, society)
        begin
          @rule.call(self, society)
        rescue Exception => error
          engine.output_warning "Error executing rule #{@name}: #{error}\n#{error.backtrace.join("\n")}"
        end
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
        return unless host.society = @society
        @modified = true
        @current_rule.modified_society = true if @current_rule
        @hosts_added += 1
      end
      
      def host_removed(host)
        return unless host.society = @society
        @modified = true
        @current_rule.modified_society = true if @current_rule
        @hosts_removed += 1
      end
      
      def node_added(node)
        return unless node.host.society = @society
        @modified = true
        @current_rule.modified_society = true if @current_rule
        @nodes_added += 1
      end
      
      def node_removed(node)
        return unless node.host.society = @society
        @modified = true
        @current_rule.modified_society = true if @current_rule
        @nodes_removed += 1
      end
      
      def agent_added(agent)
        return unless agent.node.host.society = @society
        @modified = true
        @current_rule.modified_society = true if @current_rule
        @agents_added += 1
      end
      
      def agent_removed(agent)
        return unless agent.node.host.society = @society
        @modified = true
        @current_rule.modified_society = true if @current_rule
        @agents_removed += 1
      end
      
      def component_added(component)
        return unless component.agent.node.host.society = @society
        @modified = true
        @current_rule.modified_society = true if @current_rule
        @components_added += 1
      end
      
      def component_removed(component)
        return unless component.agent.node.host.society = @society
        @modified = true
        @current_rule.modified_society = true if @current_rule
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