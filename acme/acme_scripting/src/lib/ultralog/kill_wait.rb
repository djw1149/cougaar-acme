# 
# <copyright>
# Copyright 2003 BBNT Solutions, LLC
# under sponsorship of the Defense Advanced Research Projects Agency (DARPA).

# This program is free software; you can redistribute it and/or modify
# it under the terms of the Cougaar Open Source License as published by
# DARPA on the Cougaar Open Source Website (www.cougaar.org).

# THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
# PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
# IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
# ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
# HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
# DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
# TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>

# UL Societies are not robust to agents being killed before they 
# have persisted after FindProviders. This logic lets ACME
# wait for that to be true before killing Nodes.
# Under some circumstances, a kill before persisting after
# sending GLS is also fatal, so an option (currently default) persists
# after the stage 1 GLS propogation instead

# Usage:
# do_action "WatchAgentPersists" before you do StartSociety
# Note that this sets the necessary -D argument
# Then, you can do: wait_for "NodesPersistedFindProviders" <node name>, <node name>
# Alternately, supply no Node names to wait for all Nodes to be ready.

# Also note that a Node is ready when all of its agents which
# have an SDClientPlugin have sent the Event saying they have persisted

# Note that to get the old SDClientPlugin / FindProviders persistence
# watch you must supply an argument of "false" to WatchAgentPersists

module Ultralog
  class AgentPersistWatcher
    attr_reader :agents_ready, :useSD
    # note that this won't work if the society doesn't have
    # the -D arg org.cougaar.servicediscovery.plugin.SDClientPlugin.persistEarly=true
    # and the SDClientPlugin
    # OR the -D arg org.cougaar.mlm.plugin.organization.GLSExpanderPlugin.persistEarly=true
    def initialize(run, useSD=true)
      @run = run
      @useSD = useSD

      if (! @useSD)
        @run.info_message("Watching for early persists after GLS Stage-1 propogation, not FindProviders")
      end

      @agents_ready = []
      # The real work of the watcher. Add to the list
      # of ready agents each one that sends this event
      @run.comms.on_cougaar_event do |event|
	if ((@useSD && (event.component == "SDClientPlugin" || event.component == "ALDynamicSDClientPlugin")) || (!@useSD && event.component == "GLSExpanderPlugin"))
	  unless @agents_ready.include?(event.cluster_identifier)
	    @agents_ready << event.cluster_identifier
#	    @run.info_message("Agent #{event.cluster_identifier} sent persist event")
	  end
	end
      end
    end

    # Has the named agent done its persist?
    def isAgentReady(agent)
      if agent.kind_of?(String)
	return @agents_ready.include?(agent)
      else
	return @agents_ready.include?(agent.name)
      end
    end

    # Have all agents on the named Node done their persist?
    # Only require it for agents with an SDClientPlugin
    def isNodeReady(node)
      cougaar_node = nil
      if node.kind_of?(String)
	cougaar_node = @run.society.nodes[node]
      else
	cougaar_node = node
      end
      if cougaar_node == nil
	@run.error_message("No known node #{node} to look for.")
	return(true)
      else
	cougaar_node.each_agent do |agent|
	  # If any agent on the node is not ready, then the node is not ready
	  # Only require this for
	  # agents that have an SDClientPlugin or ALDynamicSDClientPlugin
	  hasPI = false
	  agent.each_component do |comp|
	    if ((@useSD && /SDClientPlugin/.match(comp.classname)) || (!@useSD && /GLSExpanderPlugin/.match(comp.classname)))
#	      @run.info_message("Agent #{agent.name} had SDClient: #{comp.name}")
	      hasPI = true
	      break
	    end
	  end
	  if (hasPI && ! isAgentReady(agent))
#	    @run.info_message("At least one agent (#{agent.name}) not ready yet.")
	    return (false)
	  end
	end
	# No agent was not ready, so the node is ready
	return true
      end # end of else block to actually check the node
    end # end of isNodeReady

    def to_s
      return "AgentPersistWatcher"
    end
  end
end

module Cougaar

  module Actions

    # run this before you start the society so the -D arg is applied
    class WatchAgentPersists < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
	@description = "Installs the AgentPersistWatcher so we know when each agent has done its persist after FindProviders. Run this before starting the society to have it ensure the -D arg is supplied as needed."
        @parameters = [
          {:waitGLS => "optional, default=true, when true waits for GLS propogation persistence instead of FindProviders persistence."}
        ]
      }
      
      ###### To disable this new work-around, change
      # the "true" default below to false,
      # Or supply the argument "false" to WatchAgentPersists
      # in BaselineTemplate.rb
      def initialize(run, waitGLS=true)
        super(run)
        @waitGLS = waitGLS
      end

      def perform
	# Force the required -D arg to be included
	# Note that this only works if you do this before you start the society
	@run.society.each_node do |node|
          if @waitGLS
            node.override_parameter("-Dorg.cougaar.mlm.plugin.organization.GLSExpanderPlugin.persistEarly", "true")
            node.override_parameter("-Dorg.cougaar.servicediscovery.plugin.SDClientPlugin.persistEarly", "false")
          else
            node.override_parameter("-Dorg.cougaar.servicediscovery.plugin.SDClientPlugin.persistEarly", "true")
            node.override_parameter("-Dorg.cougaar.mlm.plugin.organization.GLSExpanderPlugin.persistEarly", "false")
          end
	end

	# Then install the watcher
	if @run['agent_p_watcher'] == nil
	  @run.info_message("Adding new AgentPersistWatcher")
	  @run['agent_p_watcher'] = ::Ultralog::AgentPersistWatcher.new(run, !@waitGLS)
	end
      end
    end
  end
  
  module States
    
    # Add new Action NodesPersistedSentGLS
    # that uses correct logs / comments? And supplies
    # correct args if agent persist watcher wasn't installed?
    
    # Wait for this state to ensure given nodes can be killed
    class NodesPersistedFindProviders < Cougaar::State
      DEFAULT_TIMEOUT = 30.minutes
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Waits for named Nodes to be ready to have persisted -- all agents must have persisted after FindProviders."
        @parameters = [
          {:nodes => "Nodes we want to wait for. If not given, use all in the society."}
        ]
        @example = "
          wait_for 'NodesPersistedFindProviders', 'FWD-A'
        "
      }
      
      def initialize(run, *nodes)
	super(run)
	@nodes = nodes
      end
      
      def process
	@ready_nodes = []
	if @nodes == nil || @nodes.size == 0
	  @run.info_message("Will wait for all nodes in the society.")
	  @nodes = []
	  @run.society.each_node do |node|
	    @nodes << node
	  end
	end
	if @run['agent_p_watcher'] == nil
	  @run.info_message("Late install of agent persistence watcher!")
	  @run['agent_p_watcher'] = ::Ultralog::AgentPersistWatcher.new(run)
	end

        waitGLS = !@run['agent_p_watcher'].useSD
        waitString = "finding providers"
        if waitGLS
          waitString = "sending Stage-1 GLS"
        end

        @run.info_message("Waiting for #{@nodes.size} nodes to persist after #{waitString}.")
	while (@ready_nodes.size < @nodes.size)
	  @nodes.each do |node|
	    if ! @ready_nodes.include?(node)
	      if @run['agent_p_watcher'].isNodeReady(node) 
		@ready_nodes << node
		if (node.kind_of?(String))
		  @run.info_message("Node #{node} has persisted after #{waitString}.")
		else
		  @run.info_message("Node #{node.name} has persisted after #{waitString}.")
		end
	      end # node was ready -- add it block
	    end # block to only look if not done
	  end # block to check all nodes

	  # If we're not currently done, block here waiting for
	  # the next event to come in. No point checking until it does.
	  if @ready_nodes.size < @nodes.size
	    event = @run.get_next_event
	  end
	end # end while loop waiting for all needed nodes
	# Done with the wait_for -- all needed nodes reported in
	@run.info_message("All needed nodes have persisted after #{waitString}.")
      end
      
      def unhandled_timeout
	@run.do_action "StopSociety" 
	@run.do_action "StopCommunications"
      end
    end
  end
end

