module Cougaar
  module Actions
    class TransformSociety < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Transforms the society with a list of rules."
        @parameters = [
          {:verbose => "required, If true, displays the transformations performed. (true | false)"},
          {:rules => "*rules, The rules to run.  Can be file names or directory names."}
        ]
        @example = "do_action 'TransformSociety', true, 'config/rules/isat/tic_env.rule', 'config/rules/logistics'"
      }
      
      def initialize(run, verbose, *rules)
        super(run)
        raise "Must supply rules to transform society" if rules.size==0
        @verbose = verbose
        @rules = rules
      end
      
      def perform
        @rules.each { |rule| @run.info_message "Applying #{rule}" }
        @engine = Cougaar::Model::RuleEngine.new(@run.society)
        @engine.load_rules(@rules.join(";"))
        @rules.each do |rulefile|
          if File.directory?(rulefile)
            Dir.glob(File.join(rulefile, "*.rule")).sort.each do |file|
              @run.archive_file(file, "Rule file used to transform the society")
            end
          else
            @run.archive_file(rulefile, "Rule file used to transform the society")
          end
        end
        @engine.enable_stdout if @verbose
        @engine.execute
      end
    end
  end
end

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
        list.split(";").each do |item|
          raise "Unknown file or directory: #{item}" unless File.exist?(item)
          if File.stat(item).directory?
            rules = Dir.glob(File.join(item, "*.rule")).sort
          else
            rules = [item]
          end
          rules.each do |rule_file|
            File.open(rule_file) do |file|
              rule = file.read
              begin
                @rules << Rule.new(rule_file, rule)
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
        $debug_society_model = true
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
        if @stdout_enabled
          unused_rules = []
          @rules.each do |rule|
            unused_rules << rule.name unless rule.modified_society?
          end
          if unused_rules.size > 0
            output_warning "The rule(s)s: #{unused_rules.join(', ')} did not modify the society."
          end
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
      attr_reader :society
      
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
        @society = society
        begin
          if @rule.kind_of?(String)
            instance_eval(@rule)
          else
            @rule.call(self, society)
          end
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
        ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Added #{@hosts_added} hosts.")) if @hosts_added > 0
        ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Removed #{@hosts_removed} hosts.")) if @hosts_removed > 0
        ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Added #{@nodes_added} nodes.")) if @nodes_added > 0
        ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Removed #{@nodes_removed} nodes.")) if @nodes_removed > 0
        ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Added #{@agents_added} agents.")) if @agents_added > 0
        ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Removed #{@agents_removed} agents.")) if @agents_removed > 0
        ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Added #{@components_added} components.")) if @components_added > 0
        ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Removed #{@components_removed} components.")) if @components_removed > 0
      end
    end  
  end
end
