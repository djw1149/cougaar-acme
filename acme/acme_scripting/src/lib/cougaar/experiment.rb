##
#  <copyright>
#  Copyright 2002 InfoEther, LLC
#  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the Cougaar Open Source License as published by
#  DARPA on the Cougaar Open Source Website (www.cougaar.org).
#
#  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
#  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
#  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
#  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
#  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
#  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>
#

module Cougaar

  def self.new_experiment(name, society=nil)
    return Experiment.new(name, society)
  end
  
  class ExperimentMonitor
  
    @@monitors = []
    
    def self.add(monitor)
      @@monitors << monitor
    end
    
    def self.notify_interrupt(state)
      @@monitors.each {|monitor| monitor.notify_interrupt(state)}
    end
    
    def self.notify(state_action, begin_flag)
      @@monitors.each {|monitor| monitor.notify(state_action.experiment, state_action.run, state_action, begin_flag)}
    end
  
    def self.enable_stdout
      monitor = ExperimentMonitor.new
      def monitor.on_new_experiment
        puts "[#{Time.now}] Experiment: #{current_experiment.name} started."
      end
      def monitor.on_new_run
        puts "[#{Time.now}]   Run: #{current_run.name} started."
      end
      def monitor.on_begin_state_action
        if current_state_action.kind_of? Action
          puts "[#{Time.now}]     Starting: #{current_state_action}"
        else
          puts "[#{Time.now}]     Waiting for: #{current_state_action}"
        end
      end
      def monitor.on_end_state_action
        if current_state_action.kind_of? Action
          puts "[#{Time.now}]     Finished: #{current_state_action}"
        else
          puts "[#{Time.now}]     Done: #{current_state_action}"
        end
      end
      def monitor.on_interrupted_state
        puts  "[#{Time.now}]     ** INTERRUPT ** #{current_state_action}"
      end
    end
  
    attr_reader :current_experiment, :current_run, :current_state_action
    
    def initialize
      @current_experiment = nil
      @current_run = nil
      @current_state_action = nil
      ExperimentMonitor.add(self)
    end
    
    def current_experiment=(experiment)
      @current_experiment = experiment
      on_new_experiment
    end
    
    def current_run=(run)
      @current_run = run
      on_new_run
    end
    
    def notify(experiment, run, state_action, begin_flag)
      self.current_experiment = experiment unless current_experiment==experiment
      self.current_run = run unless current_run==run
      @current_state_action = state_action
      if begin_flag
        on_begin_state_action
      else
        on_end_state_action
      end
    end
    
    def notify_interrupt(state)
      @current_state_action = state
      on_interrupted_state
    end
    
    def on_new_experiment
    end
    
    def on_new_run
    end
    
    def on_begin_state_action
    end
    
    def on_end_state_action
    end
    
    def on_interrupted_state
    end
  end

  class Experiment
    attr_accessor :name, :society
    
    def initialize(name, society=nil)
      @name = name
      @society = society
    end
    
    def run(runcount = 1, &block)
      raise "The experiment defintion must be supplied in a block to the run method" unless block_given?
      MultiRun.start(self, runcount, &block)
    end
  end
  
  class MultiRun
    attr_reader :run_count, :experiment
    def self.start(experiment, runcount, &block)
      return MultiRun.new(experiment, runcount, &block)
    end
    
    def initialize(experiment, run_count, &block)
      @run_count = run_count
      @experiment = experiment
      @run_count.times do |count|
        run = Run.new(self, count)
        run.define_run &block
        run.start
      end
    end
  end
  
  class Run
    STOPPED = 1
    STARTED = 2
    
    attr_reader :experiment, :count, :sequence, :name
    attr_accessor :comms, :society
    
    def initialize(multirun, count)
      @count = count
      @multirun = multirun
      @experiment = multirun.experiment
      @sequence = Cougaar::Sequence.new
      @stop_listeners = []
      @state = STOPPED
      @properties = {}
      @name = "#{@experiment.name}-#{count+1}of#{@multirun.run_count}"
    end
    
    def [](property)
      @properties[property]
    end
    
    def []=(property, value)
      @properties[property]=value
    end
    
    def define_run(&proc)
      instance_eval &proc
    end
    
    def wait_for(state_name, *args, &block)
      state = Cougaar::States[state_name]
      state.new(self, *args, &block)
    end
    
    def do_action(action_name, *args, &block)
      action = Cougaar::Actions[action_name]
      action.new(self, *args, &block)
    end
    
    def start
      @state = STARTED
      #TODO: logging begin
      @sequence.start
      #TODO: logging end
    end
    
    def started?
      return @state==STARTED
    end
    
    def stop
      @stop_listeners.each {|listener| listener.call}
      @state = STOPPED
    end
    
    def stopped?
      return @state==STOPPED
    end
    
    def at_stop(&block)
      @stop_listeners << block if block_given?
    end
  end
  
  class Sequence
    attr_accessor :definitions
    def initialize
      @definitions = []
      @current_definition = 0
      @run_states = []
    end
    
    def add_state(state)
      state.validate
      @definitions << state
    end
    
    def add_action(action)
      action.validate
      @definitions << action
    end
    
    def last_state?(state)
      @definitions.reverse.each do |definition|
        return true if definition.kind_of? state
        return false if definition.kind_of? Cougaar::State
      end
      return false
    end
    
    def exist?(state)
      @definitions.reverse.each do |definition|
        return true if definition.kind_of?(Cougaar::States[state])
      end
      return false
    end
    
    def interrupt(state)
      ExperimentMonitor.notify_interrupt(state)
      @definitions = @definitions[0..@definitions.index(state)]
    end
    
    def start
      count = 0
      last_state = nil
      while @definitions[count]
        ExperimentMonitor.notify(@definitions[count], true)
        if @definitions[count].kind_of? State
          last_state = @definitions[count]
          last_state.prepare
          if last_state.timed_process?
            last_state.timed_process
          else
            last_state.untimed_process
          end
        else
          begin
            @definitions[count].perform
          rescue ActionFailure => failure
            puts failure
            exit
          end
        end
        ExperimentMonitor.notify(@definitions[count], false)
        count += 1
      end
    end
  end
  
  class State
    attr_accessor :timeout, :failure_proc
    attr_reader :experiment, :run
    def initialize(run, timeout=nil, &block)
      if self.class.constants.include?("DEFAULT_TIMEOUT") && timeout.nil?
        timeout = self.class::DEFAULT_TIMEOUT
      end
      @failure_proc = block if block_given?
      @run = run
      @experiment = run.experiment
      @timeout = timeout
      @timed_out = false
      @sequence = run.sequence
      @sequence.add_state(self)
    end
    
    def to_s
      return self.class.to_s
    end
    
    def timed_out?
      return @timed_out
    end
    
    def validate
      return unless self.class.constants.include?("PRIOR_STATES")
      self.class::PRIOR_STATES.each do |state|
        unless @sequence.exist?(state)
          raise "Invalid state sequence.  #{self.class} requires a prior state of #{state}" 
        end
      end
    end

    def prepare
      @process_thread = nil
      @timer = nil
      trap("SIGINT") {
        @sequence.interrupt(self)
        begin
          on_interrupt
          handle_timeout
        rescue
          Cougaar.logger.error $!
          Cougaar.logger.error $!.backtrace.join("\n")
        end
        @timer.exit if !@timer.nil? && @timer.status
        @process_thread.exit if !@process_thread.nil? && @process_thread.status
      }
    end
    
    def timed_process?
      return !@timeout.nil?
    end
    
    def timed_process
      @process_thread = nil
      @process_thread = Thread.new do 
        @timer = Thread.new do
          sleep @timeout
          @timed_out = true
          @sequence.interrupt(self)
          begin
            on_interrupt
            handle_timeout
          rescue
            Cougaar.logger.error $!
            Cougaar.logger.error $!.backtrace.join("\n")
          end
          @process_thread.exit if @process_thread.status
        end
        begin
          process
        rescue
          puts "Exception received in #{self.class}'s process method"
          puts $!
          puts $!.backtrace
        end
        @timer.exit if @timer.status
      end
      @process_thread.join
    end
    
    def untimed_process
      @process_thread = nil
      @process_thread = Thread.new do 
        begin
          process
        rescue
          puts "Exception received in #{self.class}'s process method"
          puts $!
          puts $!.backtrace
        end
      end
      @process_thread.join
    end

    def process
      raise "Unprocessed process method for class: #{self.class}"
    end
    
    def handle_timeout
      if @failure_proc
        @failure_proc.call(self)
      else
        unhandled_timeout
      end
    end

    def on_interrupt
    end
    
    def unhandled_timeout
    end
    
  end
  
  class NOOPState < State
    def process
    end
  end
  
  class Action
    attr_accessor :sequence
    attr_reader :run, :experiment
    def initialize(run)
      @run = run
      @experiment = run.experiment
      @sequence = run.sequence
      @sequence.add_action(self)
      if self.class.constants.include?("RESULTANT_STATE")
        @run.wait_for(self.class::RESULTANT_STATE)
      end
    end
    
    def validate
      return unless self.class.constants.include?("PRIOR_STATES")
      self.class::PRIOR_STATES.each do |state|
        unless @sequence.exist?(state)
          raise "Invalid action sequence.  #{self.class} requires a prior state of #{state}" 
        end
      end
    end
    
    def raise_failure(message, root_exception=nil)
      raise ActionFailure.new(self, message, root_exception)
    end
    
    def perform
      raise "Unimplemented perform method for class: #{self.class}"
    end
    
    def to_s
      return self.class.to_s
    end
    
    
  end
  
  class ActionFailure < Exception
    attr_reader :action, :message, :root_exception
    def initialize(action, message, root_exception=nil)
      @action = action
      @message = message
      @root_exception = root_exception
    end
    
    def to_s
      puts "ActionFailure for action: #{@action.class}"
      puts "  #{message}"
      if @root_exception
        puts "EXCEPTION REPORT: \n#{@root_exception}"
        @root_exception.backtrace.join("\n")
      end
    end
  end
  
  module Actions
    def self.each
      Actions.constants.each do |c|
        obj = (eval c)
        if obj.class == Class && obj.superclass == Cougaar::Action
          yield obj
        end
      end
    end
    
    def self.[](name)
      raise "Unknown action: #{name}" unless Actions.constants.include?(name)
      Actions.module_eval(name)
    end
    
    def self.has_action?(name)
      return Actions.constants.include?(name)
    end
  end
  
  module States
    def self.each
      States.constants.each do |c|
        obj = (eval c)
        if obj.class == Class && obj.superclass == Cougaar::State
          yield obj
        end
      end
    end
    
    def self.[](name)
      raise "Unknown state: #{name}" unless States.constants.include?(name)
      States.module_eval(name)
    end
    
    def self.exist?(name)
      return States.constants.include?(name)
    end
  end
end

module Cougaar
  module Actions
    class GenericAction < Cougaar::Action
      def initialize(run, &block)
        super(run)
        raise "Must supply block for GenericAction" unless block_given?
        @action = block
      end
      def perform
        @action.call(@run)
      end
    end
    class ExperimentSucceeded < Cougaar::Action
      attr_reader :message
      def initialize(run, message=nil)
        super(run)
        @message = message
      end
      def perform
      end
    end
    class ExperimentFailed < Cougaar::Action
      attr_reader :message
      def initialize(run, message=nil)
        super(run)
        @message = message
      end
      def perform
      end
    end
 
  end
end

