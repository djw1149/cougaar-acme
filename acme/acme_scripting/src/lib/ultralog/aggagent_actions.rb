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

require 'ultralog/aggagent'

module UltraLog
  module AggAgent
    class AggAgentBase < ::Cougaar::Action
      def initialize(run, file)
        super(run)
        @file = file
      end
      def save(result)
        File.open(@file, "wb") do |file|
          file.puts result
        end
      end
    end
  end
end

module Cougaar
  module Actions
    class AggAgentQueryBasic < ::UltraLog::AggAgent::AggAgentBase
      DOCUMENTATION = Cougaar.document {
        @description = "Perform basic AggAgent query on inventory and write results to a file."
        @parameters = [
          {:file => "required, The file name to write to."}
        ]
        @example = "do_action 'AggAgentQueryBasic', 'agg_agent_basic.xml'"
      }
      def perform
        begin
          @uri = @run.society.agents['AGG-Agent'].uri
          client = UltraLog::AggAgent::Client.new(@uri)
          result = client.submit_query do |query|
            query.type = UltraLog::AggAgent::Query::TYPE_TRANSIENT
            query.name="Test Query"
            query.source_clusters.concat ["1-35-ARBN","1-501-AVNBN","1-6-INFBN","47-FSB","123-MSB","592-ORDCO","191-ORDBN","227-SUPPLYCO","343-SUPPLYCO", "565-RPRPTCO","102-POL-SUPPLYCO", "110-POL-SUPPLYCO","127-DASB"]
            query.timeout = 300000
            query.predicate_spec = UltraLog::AggAgent::ScriptSpec.new_predicate_spec do |spec|
              spec.language = UltraLog::AggAgent::ScriptSpec::LANG_JAVA
              spec.text = "org.cougaar.logistics.ui.stoplight.society.InventoryRelatedPredicate"
              spec.parameters["AssetsOfInterest"]  = "NSN/8960013687383,NSN/8920012959276,NSN/8970014330561,NSN/8920001327782,NSN/8970001491094,NSN/9150002698255,NSN/9150009268963,NSN/9150000825636,NSN/9140002865294,NSN/9130010315816,DODIC/A576,DODIC/G815,DODIC/G826,DODIC/C787,DODIC/C380,NSN/1615011643777,NSN/1560011797265,NSN/2915010948577,NSN/2620011634647,NSN/5995010901634,NSN/2520000013530,NSN/2520012073534,NSN/2920013003737,NSN/2940009092453,NSN/2990010408852,NSN/5930012319257,NSN/6150010729992,NSN/1650001826527,NSN/4930011310106,NSN/4810011449169"
            end
            query.format_spec = UltraLog::AggAgent::ScriptSpec.new_format_spec do |spec|
              spec.language = UltraLog::AggAgent::ScriptSpec::LANG_JAVA
              spec.text = "org.cougaar.logistics.ui.stoplight.society.MetricFormatter"
              spec.format = UltraLog::AggAgent::ScriptSpec::FORMAT_INCREMENT
              spec.parameters["StartTime"]=0
              spec.parameters["MetricFormulas"]="Inventory"
              spec.parameters["AggregateTime"]=false
              spec.parameters["MetricNames"]="Inventory"
              spec.parameters["EndTime"]=300
              spec.parameters["AggregationScheme"]='<aggregation org="1" time="4" item="0"/>'
              spec.parameters["ItemFixed"]=false
            end
          end
          save(result)
        rescue
          result = "<AggAgentException>\n"
          result += $!
          result += "\n"
          result += $!.backtrace.join("\n")
          result += "\n</AggAgentException>"
          save(result)
        end
      end
    end
  
    class AggAgentQueryShortfall < ::UltraLog::AggAgent::AggAgentBase
      DOCUMENTATION = Cougaar.document {
        @description = "Perform AggAgent query on shortfall and write results to a file."
        @parameters = [
          {:file => "required, The file name to write to."}
        ]
        @example = "do_action 'AggAgentQueryShortfall', 'agg_agent_shortfall.xml'"
      }
      def perform
        begin
          @uri = @run.society.agents['AGG-Agent'].uri
          client = UltraLog::AggAgent::Client.new(@uri)
          result = client.submit_query do |query|
            query.type = UltraLog::AggAgent::Query::TYPE_TRANSIENT
            query.name="Test Query"
            query.source_clusters.concat ["1-35-ARBN","1-501-AVNBN","1-6-INFBN","47-FSB","123-MSB","592-ORDCO","191-ORDBN","227-SUPPLYCO","343-SUPPLYCO", "565-RPRPTCO","102-POL-SUPPLYCO", "110-POL-SUPPLYCO","127-DASB"]
            query.timeout = 300000
            query.predicate_spec = UltraLog::AggAgent::ScriptSpec.new_predicate_spec do |spec|
              spec.language = UltraLog::AggAgent::ScriptSpec::LANG_JAVA
              spec.text = "org.cougaar.logistics.ui.stoplight.society.InventoryRelatedPredicate"
              spec.parameters["AssetsOfInterest"]  = "NSN/8960013687383,NSN/8920012959276,NSN/8970014330561,NSN/8920001327782,NSN/8970001491094,NSN/9150002698255,NSN/9150009268963,NSN/9150000825636,NSN/9140002865294,NSN/9130010315816,DODIC/A576,DODIC/G815,DODIC/G826,DODIC/C787,DODIC/C380,NSN/1615011643777,NSN/1560011797265,NSN/2915010948577,NSN/2620011634647,NSN/5995010901634,NSN/2520000013530,NSN/2520012073534,NSN/2920013003737,NSN/2940009092453,NSN/2990010408852,NSN/5930012319257,NSN/6150010729992,NSN/1650001826527,NSN/4930011310106,NSN/4810011449169"
            end
            query.format_spec = UltraLog::AggAgent::ScriptSpec.new_format_spec do |spec|
              spec.language = UltraLog::AggAgent::ScriptSpec::LANG_JAVA
              spec.text = "org.cougaar.logistics.ui.stoplight.society.MetricFormatter"
              spec.format = UltraLog::AggAgent::ScriptSpec::FORMAT_INCREMENT
              spec.parameters["StartTime"]=0
              spec.parameters["MetricFormulas"]="Requested Due In,Projected Requested Due In,+,Due In,Projected Due In,+,-"
              spec.parameters["AggregateTime"]=false
              spec.parameters["MetricNames"]="Requested Due In Minus Due In"
              spec.parameters["EndTime"]=300
              spec.parameters["AggregationScheme"]='<aggregation org="1" time="4" item="0"/>'
              spec.parameters["ItemFixed"]=false
            end
          end
          save(result)
        rescue
          result = "<AggAgentException>\n"
          result += $!
          result += "\n"
          result += $!.backtrace.join("\n")
          result += "\n</AggAgentException>"
          save(result)
        end
      end
    end
    
    class AggAgentQueryDemand < ::UltraLog::AggAgent::AggAgentBase
      DOCUMENTATION = Cougaar.document {
        @description = "Perform AggAgent query on demand and write results to a file."
        @parameters = [
          {:file => "required, The file name to write to."}
        ]
        @example = "do_action 'AggAgentQueryDemand', 'agg_agent_demand.xml'"
      }
      def perform
        begin
          @uri = @run.society.agents['AGG-Agent'].uri
          client = UltraLog::AggAgent::Client.new(@uri)
          result = client.submit_query do |query|
            query.type = UltraLog::AggAgent::Query::TYPE_TRANSIENT
            query.name="Test Query"
            query.source_clusters.concat ["102-POL-SUPPLYCO","106-TCBN","109-MDM-TRKCO","110-POL-SUPPLYCO","1-13-ARBN","11-AVN-RGT","1-1-CAVSQDN","123-MSB","125-FSB","125-ORDBN","127-DASB","1-27-FABN","12-AVNBDE","130-ENGBDE","1-35-ARBN","1-36-INFBN","1-37-ARBN","1-41-INFBN","141-SIGBN","1-4-ADABN","1-501-AVNBN","15-PLS-TRKCO","16-CSG","16-ENGBN","1-6-INFBN","181-TCBN","18-MAINTBN","18-MPBDE","18-PERISH-SUBPLT","191-ORDBN","1-94-FABN","19-MMC","1-AD","1-AD-DIV","1-BDE-1-AD","200-MMC","205-MIBDE","208-SCCO","21-TSC-HQ","226-MAINTCO","227-SUPPLYCO","22-SIGBDE","2-37-ARBN","238-POL-TRKCO","2-3-FABN","23-ORDCO","240-SSCO","244-ENGBN-CBTHVY","2-4-FABN-MLRS","24-ORDCO","2-501-AVNBN","25-FABTRY-TGTACQ","263-FLDSVC-CO","2-6-INFBN","26-SSCO","2-70-ARBN","27-TCBN-MVTCTRL","286-ADA-SCCO","28-TCBN","29-SPTGP","2-BDE-1-AD","30-MEDBDE","3-13-FABN-155","316-POL-SUPPLYBN","317-MAINTCO","343-SUPPLYCO","372-CGO-TRANSCO","377-HVY-TRKCO","37-TRANSGP","3-BDE-1-AD","3-SUPCOM-HQ","40-ENGBN","416-POL-TRKCO","41-FABDE","4-1-FABN","41-POL-TRKCO","4-27-FABN","452-ORDCO","47-FSB","485-CSB","501-FSB","501-MIBN-CEWI","501-MPCO","512-MAINTCO","515-POL-TRKCO","51-MAINTBN","51-MDM-TRKCO","529-ORDCO","52-ENGBN-CBTHVY","541-POL-TRKCO","561-SSBN","565-RPRPTCO","574-SSCO","584-MAINTCO","588-MAINTCO","592-ORDCO","594-MDM-TRKCO","596-MAINTCO","597-MAINTCO","5-CORPS","5-CORPS-ARTY","5-CORPS-REAR","5-MAINTCO","632-MAINTCO","66-MDM-TRKCO","68-MDM-TRKCO","69-ADABDE","69-CHEMCO","6-TCBN","702-EODDET","70-ENGBN","71-MAINTBN","71-ORDCO","720-EODDET","77-MAINTCO","7-CSG","7-TCGP-TPTDD","900-POL-SUPPLYCO","AVNBDE-1-AD","AWR-2","DISCOM-1-AD","DIVARTY-1-AD","DLAHQ","FORSCOM","HNS","JSRCMDSE","NATO","NCA","OSC","RSA","USAEUR","USEUCOM"]
            query.timeout = 300000
            query.predicate_spec = UltraLog::AggAgent::ScriptSpec.new_predicate_spec do |spec|
              spec.language = UltraLog::AggAgent::ScriptSpec::LANG_JAVA
              spec.text = "org.cougaar.logistics.ui.stoplight.society.InventoryRelatedPredicate"
              spec.parameters["AssetsOfInterest"]  = "NSN/9130010315816"
            end
            query.format_spec = UltraLog::AggAgent::ScriptSpec.new_format_spec do |spec|
              spec.language = UltraLog::AggAgent::ScriptSpec::LANG_JAVA
              spec.text = "org.cougaar.logistics.ui.stoplight.society.MetricFormatter"
              spec.format = UltraLog::AggAgent::ScriptSpec::FORMAT_INCREMENT
              spec.parameters["StartTime"]=0
              spec.parameters["MetricFormulas"]="Requested Due Out,Projected Requested Due Out,+"
              spec.parameters["AggregateTime"]=false
              spec.parameters["MetricNames"]="Demand"
              spec.parameters["EndTime"]=300
              spec.parameters["AggregationScheme"]='<aggregation org="1" time="4" item="0"/>'
              spec.parameters["ItemFixed"]=false
            end
          end
          save(result)
        rescue
          result = "<AggAgentException>\n"
          result += $!
          result += "\n"
          result += $!.backtrace.join("\n")
          result += "\n</AggAgentException>"
          save(result)
        end
      end
    end
    
    class AggAgentQueryJP8 < ::UltraLog::AggAgent::AggAgentBase
      DOCUMENTATION = Cougaar.document {
        @description = "Perform AggAgent query on JP8 and write results to a file."
        @parameters = [
          {:file => "required, The file name to write to."}
        ]
        @example = "do_action 'AggAgentQueryJP8', 'agg_agent_jp8.xml'"
      }
      def perform
        begin
          @uri = @run.society.agents['AGG-Agent'].uri
          client = UltraLog::AggAgent::Client.new(@uri)
          result = client.submit_query do |query|
            query.type = UltraLog::AggAgent::Query::TYPE_TRANSIENT
            query.name="Test Query"
            query.source_clusters.concat ["2-70-ARBN","2-501-AVNBN","2-37-ARBN","1-501-AVNBN","1-37-ARBN","1-35-ARBN","1-1-CAVSQDN","1-13-ARBN","102-POL-SUPPLYCO","110-POL-SUPPLYCO","123-MSB","127-DASB","125-FSB","47-FSB","501-FSB"]
            query.timeout = 300000
            query.predicate_spec = UltraLog::AggAgent::ScriptSpec.new_predicate_spec do |spec|
              spec.language = UltraLog::AggAgent::ScriptSpec::LANG_JAVA
              spec.text = "org.cougaar.logistics.ui.stoplight.society.InventoryRelatedPredicate"
              spec.parameters["AssetsOfInterest"]  = "NSN/9130010315816"
            end
            query.format_spec = UltraLog::AggAgent::ScriptSpec.new_format_spec do |spec|
              spec.language = UltraLog::AggAgent::ScriptSpec::LANG_JAVA
              spec.text = "org.cougaar.logistics.ui.stoplight.society.MetricFormatter"
              spec.format = UltraLog::AggAgent::ScriptSpec::FORMAT_INCREMENT
              spec.parameters["StartTime"]=0
              spec.parameters["MetricFormulas"]="Inventory"
              spec.parameters["AggregateTime"]=false
              spec.parameters["MetricNames"]="Inventory"
              spec.parameters["EndTime"]=300
              spec.parameters["AggregationScheme"]='<aggregation org="1" time="4" item="0"/>'
              spec.parameters["ItemFixed"]=false
            end
          end
          save(result)
        rescue
          result = "<AggAgentException>\n"
          result += $!
          result += "\n"
          result += $!.backtrace.join("\n")
          result += "\n</AggAgentException>"
          save(result)
        end
      end
    end
  end
end

