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

require 'thread'

module Cougaar

  def self.new_experiment(name, society=nil)
    return Experiment.new(name, society)
  end
  
  class ExperimentMonitor
  
    @@monitors = []
    
    ExperimentNotification = Struct.new(:experiment, :begin_flag)
    RunNotification = Struct.new(:run, :begin_flag)
    StateNotification = Struct.new(:state, :begin_flag)
    ActionNotification = Struct.new(:action, :begin_flag)
    InterruptNotification = Struct.new(:state)
    InfoNotification = Struct.new(:message)
    ErrorNotification = Struct.new(:message)
    
    def self.add(monitor)
      @@monitors << monitor
    end
    
    def self.active?
      return (@@monitors.size > 0)
    end
    
    def self.notify(notification)
      @@monitors.each {|monitor| monitor.notify(notification)}
    end
  
    def self.enable_stdout
      monitor = ExperimentMonitor.new
      
      def monitor.on_experiment_begin(experiment)
        puts "[#{Time.now}] Experiment: #{experiment.name} started."
      end
      def monitor.on_experiment_end(experiment)
        puts "[#{Time.now}] Experiment: #{experiment.name} finished."
      end
      
      def monitor.on_run_begin(run)
        puts "[#{Time.now}]   Run: #{run.name} started."
      end
      def monitor.on_run_end(run)
        puts "[#{Time.now}]   Run: #{run.name} finished."
      end
      
      def monitor.on_state_begin(state)
        puts "[#{Time.now}]     Waiting for: #{state}"
      end
      def monitor.on_state_end(state)
        puts "[#{Time.now}]     Done: #{state}"
      end
      
      def monitor.on_action_begin(action)
        puts "[#{Time.now}]     Starting: #{action}"
      end
      def monitor.on_action_end(action)
        puts "[#{Time.now}]     Finished: #{action}"
      end
      
      def monitor.on_state_interrupt(state)
        puts  "[#{Time.now}]      ** INTERRUPT ** #{state}"
      end
      
      def monitor.on_info_message(message)
        puts  "[#{Time.now}]      INFO: #{message}"
      end
      
      def monitor.on_error_message(message)
        puts  "[#{Time.now}]      ERROR: #{message}"
      end
    end
  
    def self.enable_logging
      monitor = ExperimentMonitor.new
      
      def monitor.on_experiment_begin(experiment)
        Cougaar.logger.info "[#{Time.now}] Experiment: #{experiment.name} started."
      end
      def monitor.on_experiment_end(experiment)
        Cougaar.logger.info  "[#{Time.now}] Experiment: #{experiment.name} finished."
      end
      
      def monitor.on_run_begin(run)
        Cougaar.logger.info  "[#{Time.now}]   Run: #{run.name} started."
      end
      def monitor.on_run_end(run)
        Cougaar.logger.info  "[#{Time.now}]   Run: #{run.name} finished."
      end
      
      def monitor.on_state_begin(state)
        Cougaar.logger.info  "[#{Time.now}]     Waiting for: #{state}"
      end
      def monitor.on_state_end(state)
        Cougaar.logger.info  "[#{Time.now}]     Done: #{state}"
      end
      
      def monitor.on_action_begin(action)
        Cougaar.logger.info  "[#{Time.now}]     Starting: #{action}"
      end
      def monitor.on_action_end(action)
        Cougaar.logger.info  "[#{Time.now}]     Finished: #{action}"
      end
      
      def monitor.on_state_interrupt(state)
        Cougaar.logger.info  "[#{Time.now}]      ** INTERRUPT ** #{state}"
      end
      def monitor.on_info_message(message)
        Cougaar.logger.info  "[#{Time.now}]      INFO: #{message}"
      end
      def monitor.on_error_message(message)
        Cougaar.logger.error "[#{Time.now}]      ERROR: #{message}"
      end
    end
  
    def initialize
      ExperimentMonitor.add(self)
    end
    
    def notify(n)
      
      if n.kind_of? ExperimentNotification
        n.begin_flag ? on_experiment_begin(n.experiment) : on_experiment_end(n.experiment)
      elsif n.kind_of? RunNotification
        n.begin_flag ? on_run_begin(n.run) : on_run_end(n.run)
      elsif n.kind_of? StateNotification
        n.begin_flag ? on_state_begin(n.state) : on_state_end(n.state)
      elsif n.kind_of? ActionNotification
        n.begin_flag ? on_action_begin(n.action) : on_action_end(n.action)
      elsif n.kind_of? InterruptNotification
        on_state_interrupt(n.state)
      elsif n.kind_of? InfoNotification
        on_info_message(n.message)
      elsif n.kind_of? ErrorNotification
        on_error_message(n.message)
      end
    end
    
    def notify_interrupt(state)
      @current_state_action = state
      on_interrupted_state
    end
    
    def on_experiment_begin(experiment)
    end
    
    def on_experiment_end(experiment)
    end
    
    def on_run_begin(run)
    end
    
    def on_run_end(run)
    end
    
    def on_state_begin(state)
    end
    
    def on_state_end(state)
    end
    
    def on_action_begin(action)
    end
    
    def on_action_end(action)
    end
    
    def on_state_interrupt(state)
    end
    
    def on_info_message(message)
    end
    
    def on_error_message(message)
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
      ExperimentMonitor.notify(ExperimentMonitor::ExperimentNotification.new(self, true)) if ExperimentMonitor.active?
      MultiRun.start(self, runcount, &block)
      ExperimentMonitor.notify(ExperimentMonitor::ExperimentNotification.new(self, false)) if ExperimentMonitor.active?
    end
  end
  
  class MultiRun
    attr_reader :run_count, :experiment
    def self.start(experiment, runcount, &block)
      return MultiRun.new(experiment, runcount, &block)
    end
    
    def initialize(experiment, run_count, &block)
      @run_count = run_count
      @interrupted = false
      @experiment = experiment
      @run_count.times do |count|
        run = Run.new(self, count)
        run.define_run &block
        run.start
        return if interrupted?
      end
    end
    
    def interrupted?
      @interrupted
    end
    
    def interrupt
      @interrupted = true
    end
  end
  
  class CougaarEventQueue
    def initialize()
      @q     = []
      @mutex = Mutex.new
      @cond  = ConditionVariable.new
    end
  
    def enqueue(*elems)
      @mutex.synchronize do
        @q.push *elems
        @cond.signal
      end
    end
  
    def dequeue()
      @mutex.synchronize do
        while @q.empty? do
          @cond.wait(@mutex)
        end
  
        return @q.shift
      end
    end
  
    def empty?()
      @mutex.synchronize do
        return @q.empty?
      end
    end
  end
  
  class Run
    STOPPED = 1
    STARTED = 2
    
    attr_reader :experiment, :count, :sequence, :name, :comms
    attr_accessor :society
    
    def initialize(multirun, count)
      @count = count
      @multirun = multirun
      @experiment = multirun.experiment
      @sequence = Cougaar::Sequence.new
      @stop_listeners = []
      @state = STOPPED
      @properties = {}
      @name = "#{@experiment.name}-#{count+1}of#{@multirun.run_count}"
      @event_queue = CougaarEventQueue.new
      @include_stack = []
      @include_stack.push []
    end
    
    def comms=(comms)
      @comms = comms
      @comms.on_cougaar_event do |event|
        @event_queue.enqueue(event)
      end
    end
    
    def include_args
      @include_stack.last
    end
    
    def get_next_event
      @event_queue.dequeue
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
    
    def include(file, *include_args)
      @include_stack.push include_args
      raise "Cannot find file to include: #{file}" unless File.exist?(file)
      File.open(file, "r") do |f|
        instance_eval f.read
      end
      @include_stack.pop
    end
    
    def continue
      @sequence.continue
    end
    
    def start
      ExperimentMonitor.notify(ExperimentMonitor::RunNotification.new(self, true)) if ExperimentMonitor.active?
      @state = STARTED
      #TODO: logging begin
      @sequence.start
      ExperimentMonitor.notify(ExperimentMonitor::RunNotification.new(self, false)) if ExperimentMonitor.active?
      #TODO: logging end
    end
    
    def interrupt
      @multirun.interrupt
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
    
    def info_message(message)
      ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new(message)) if ExperimentMonitor.active?
    end
    
    def error_message(message)
      ExperimentMonitor.notify(ExperimentMonitor::ErrorNotification.new(message)) if ExperimentMonitor.active?
    end
    
  end
  
  class Sequence
    attr_accessor :definitions
    def initialize
      @definitions = []
      @current_definition = 0
      @started = false
      @insert_index = 0
    end
    
    def add_state(state)
      if @started
        @definitions = @definitions[0..@insert_index]+[state]+@definitions[(@insert_index+1)..-1]
        @insert_index += 1
      else
        state.validate
        @definitions << state
      end
    end
    
    def add_action(action)
      if @started
        @definitions = @definitions[0..@insert_index]+[action]+@definitions[(@insert_index+1)..-1]
        @insert_index += 1
      else
        action.validate
        @definitions << action
      end
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
    
    def continue
      @continue_after_timeout = true
    end
    
    def interrupt
      if @continue_after_timeout
        @continue_after_timeout = false
        ExperimentMonitor.notify(ExperimentMonitor::ErrorNotification.new("Continuing from failed state #{@definitions[@current_definition].name}...")) if ExperimentMonitor.active?
        return
      end
      state = @definitions[@current_definition]
      ExperimentMonitor.notify(ExperimentMonitor::InterruptNotification.new(state)) if ExperimentMonitor.active?
      @definitions = @definitions[0..@insert_index] 
    end
    
    def start
      @current_definition = 0
      @started = true
      last_state = nil
      while @definitions[@current_definition]
        @insert_index = @current_definition
        if @definitions[@current_definition].kind_of? State
          ExperimentMonitor.notify(ExperimentMonitor::StateNotification.new(@definitions[@current_definition], true)) if ExperimentMonitor.active?
          last_state = @definitions[@current_definition]
          last_state.prepare
          if last_state.timed_process?
            last_state.timed_process
          else
            last_state.untimed_process
          end
          ExperimentMonitor.notify(ExperimentMonitor::StateNotification.new(@definitions[@current_definition], false)) if ExperimentMonitor.active?
        else
          ExperimentMonitor.notify(ExperimentMonitor::ActionNotification.new(@definitions[@current_definition], true)) if ExperimentMonitor.active?
          begin
            @definitions[@current_definition].perform
          rescue ActionFailure => failure
            puts failure
            exit
          ensure
            ExperimentMonitor.notify(ExperimentMonitor::ActionNotification.new(@definitions[@current_definition], false)) if ExperimentMonitor.active?
          end
        end
        @current_definition += 1
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

    def info_message(message)
      ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new(message)) if ExperimentMonitor.active?
    end
    
    def error_message(message)
      ExperimentMonitor.notify(ExperimentMonitor::ErrorNotification.new(message)) if ExperimentMonitor.active?
    end
    
    def to_s
      return self.name
    end
    
    def is_noop?
      return self.class.ancestors.include?(Cougaar::NOOPState)
    end
    
    def default_timeout
      if self.class.constants.include?("DEFAULT_TIMEOUT")
        return self.class::DEFAULT_TIMEOUT
      end
    end

    def prior_states
      if self.class.constants.include?("PRIOR_STATES")
        return self.class::PRIOR_STATES
      end
    end
    
    def documentation
      if self.class.constants.include?("DOCUMENTATION")
        return self.class::DOCUMENTATION
      end
    end
    
    def name
      self.class.to_s.split("::")[2]
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
        @sequence.interrupt
        @run.interrupt
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
          begin
            on_interrupt
            handle_timeout
          rescue
            Cougaar.logger.error $!
            Cougaar.logger.error $!.backtrace.join("\n")
          end
          @sequence.interrupt
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
    
    def info_message(message)
      ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new(message)) if ExperimentMonitor.active?
    end
    
    def error_message(message)
      ExperimentMonitor.notify(ExperimentMonitor::ErrorNotification.new(message)) if ExperimentMonitor.active?
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
      return self.name
    end
    
    def resultant_state
      if self.class.constants.include?("RESULTANT_STATE")
        return self.class::RESULTANT_STATE
      end
    end
    
    def prior_states
      if self.class.constants.include?("PRIOR_STATES")
        return self.class::PRIOR_STATES
      end
    end
    
    def documentation
      if self.class.constants.include?("DOCUMENTATION")
        return self.class::DOCUMENTATION
      end
    end
    
    def name
      self.class.to_s.split("::")[2]
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
        if obj.class == Class && obj.ancestors.include?(Cougaar::Action)
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
        if obj.class == Class && obj.ancestors.include?(Cougaar::State)
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
      DOCUMENTATION = Cougaar.document {
        @description = "The GenericAction Action is useful for performing any 
                       ad hoc processing during a run, such as waiting (sleeping) 
                       for a period of time, or any other task."
        @block_yields = [
          :run => "The run object (Cougaar::Experiment::Run)"
        ]
        @example = "
          do_action 'GenericAction' do |run|
            sleep 3.minutes
          end
        "
      }
      def initialize(run, &block)
        super(run)
        raise "Must supply block for GenericAction" unless block_given?
        @action = block
      end
      def perform
        @action.call(@run)
      end
    end
    
    class InfoMessage < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Sends an informational message to experiment monitors"
        @parameters = [
          :message => "The message to send"
        ]
        @example = "do_action 'InfoMessage', 'Doing Stuff'"
      }
      def initialize(run, message)
        super(run)
        @message = message
      end
      def perform
        @run.info_message "#{@message}"
      end
    end

    class ErrorMessage < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Sends an error message to experiment monitors"
        @parameters = [
          :message => "The message to send"
        ]
        @example = "do_action 'ErrorMessage', 'This was bad'"
      }
      def initialize(run, message)
        super(run)
        @message = message
      end
      def perform
        @run.error_message "#{@message}"
      end
    end
    
    class Sleep < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Sleep the script for the specified number of seconds."
        @parameters = [
          :seconds => "Number of seconds to sleep (Numeric)"
        ]
        @example = "do_action 'Sleep', 5.minutes"
      }
      def initialize(run, seconds)
        super(run)
        @seconds = seconds
      end
      def to_s
        return super.to_s + "(#{@seconds/60.0} minutes)"
      end
      def perform
        sleep @seconds
      end
    end
    class ExperimentSucceeded < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Marker action to document that the experiment succeeded."
        @parameters = [
          :message => "default=nil, the message to output"
        ]
        @example = "do_action 'ExperimentSucceeded', 'Finished full run'"
      }
      attr_reader :message
      def initialize(run, message=nil)
        super(run)
        @message = message
      end
      def perform
      end
    end
    class ExperimentFailed < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Marker action to document that the experiment failed."
        @parameters = [
          :message => "default=nil, the message to output"
        ]
        @example = "do_action 'ExperimentFailed', 'Failed to get planning complete'"
      }
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

