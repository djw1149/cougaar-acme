#!/usr/bin/ruby --
##Inventory Verifier
##Compares Inventory XML files with benchmarks 

require 'parsedate'

module ACME
  module Plugins

    DEMAND_REQUISITION = "WITHDRAW_TASKS"
    DEMAND_PROJECTION =  "COUNTED_PROJECTWITHDRAW_TASKS"
    DEMAND_REQUISITION_RESPONSE = "WITHDRAW_TASK_ALLOCATION_RESULTS"
    DEMAND_PROJECTION_RESPONSE = "COUNTED_PROJECTWITHDRAW_TASK_ALLOCATION_RESULTS"

    REFILL_REQUISITION = "RESUPPLY_SUPPLY_TASKS"
    REFILL_PROJECTION =  "RESUPPLY_PROJECTSUPPLY_TASKS"
    REFILL_REQUISITION_RESPONSE = "RESUPPLY_SUPPLY_TASK_ALLOCATION_RESULTS"
    REFILL_PROJECTION_RESPONSE = "RESUPPLY_PROJECTSUPPLY_TASK_ALLOCATION_RESULTS"

    LEVELS = "INVENTORY_LEVELS"

    ONE_HOUR = 3600 # = 60 * 60
    ONE_DAY = ONE_HOUR * 24

    InventoryTestData = Struct.new("InventoryTestData", :subject_file, :benchmark_file, :stage, :errors, :error_level)
    InventoryTestError = Struct.new("InventoryTestError", :day, :tag, :subject_value, :benchmark_value, :tolerance)
    InventoryTestCriticalError = Struct.new("InventoryTestCriticalError", :msg)
    
    SUCCESS = 0
    PARTIAL = 1
    FAIL = 2


    class InventoryRecord
      attr_reader :start_time, :end_time, :value
    
      def initialize(s, e, v)
        @start_time = (s.class == Time ? s.gmtime : Time.at(s).gmtime)
        @end_time = (e.class == Time ? e.gmtime : Time.at(e).gmtime)
        @end_time += 1 if (@start_time == @end_time)
        @value = v
      end
    
      def <=> (rec)
        return @start_time <=> rec.start_time
      end
    
      #given another record return the disjoint intervals that make up both
      def merge(rec)
        return [self, rec].sort unless self.overlap(rec)
        new_recs = []
        times = [@start_time, @end_time, rec.start_time, rec.end_time].uniq.sort
        times.each_index do |i|
            break if (i == times.length - 1)
            new_recs.push(InventoryRecord.new(times[i], times[i+1], value_at(times[i]) + rec.value_at(times[i])))
        end
        return new_recs
      end
    
      def overlap(rec)
        return true if (@start_time >= rec.start_time) && (@start_time < rec.end_time)
        return true if (rec.start_time >= @start_time) && (rec.start_time < @end_time)
        return true if (rec.start_time == @start_time) && (rec.end_time == @end_time)
        return false
      end
    
      def to_s
        return "#{@start_time} #{@end_time} #{@value}"
      end

      def value_at(time)
        time = Time.at(time) unless time.class == Time
        time.gmtime unless time.gmt?
        return @value if (((@start_time < time) && (@end_time > time)) || @start_time == time)
        return 0
      end
    
      def in_range(time)
        return (@start_time <= time && time < end_time)
      end
    end

    class TagData
      attr_reader :tag, :data

      def initialize(tag, scale_to_day)
        @tag = tag
        @data = []
        @scale = scale_to_day
      end

      def add_record(start_time, end_time, value)
        new_recs = []
        numeric_value = value.to_f

        start_time = Time.gm(*ParseDate.parsedate(start_time)).to_i # convert time in strings to integer
        end_time = Time.gm(*ParseDate.parsedate(end_time)).to_i


        if @scale then 
          if (start_time % ONE_DAY != 0) then
            new_recs.push(InventoryRecord.new(round_to_day(start_time, false), 
                                round_to_day(start_time, true), 
                                get_fraction_of_day(start_time, false) * numeric_value))
          end
          if (round_to_day(start_time, true) != round_to_day(end_time, false)) then
            new_recs.push(InventoryRecord.new(round_to_day(start_time, true),
                                round_to_day(end_time, false), numeric_value))
          end
          if (end_time % ONE_DAY != 0) then
            new_recs.push(InventoryRecord.new(round_to_day(end_time, false), 
                              round_to_day(end_time, true), 
                              get_fraction_of_day(end_time, true) * numeric_value))
          end
        else
          new_recs.push(InventoryRecord.new(round_to_day(end_time, false),
                                  round_to_day(end_time, true), numeric_value))
        end
        new_recs.each do |rec|
          add_one_record(rec)
        end
      end

      def delta_days
        ddays = []
        @data.each do |rec|
          ddays.push(rec.start_time)
        end
        return ddays.uniq
      end
    
      def last_day
        return Time.at(0).gmtime if @data.empty?
        return @data.last.end_time
      end
    
      def delete_before_time(time)
        while(!@data.empty? && @data[0].start_time <= time) do
            first = @data.shift
        end
        if (!first.nil? && first.end_time > time + ONE_DAY) then
            @data.unshift(InventoryRecord.new(time + ONE_DAY, first.end_time, first.value))
        end
      end
        

      def max_value
        max = 0
        @data.each do |rec|
            max = rec.value if rec.value > max
        end
        return max
      end

      def value_at(time)
        @data.each do |rec|
          next unless rec.in_range(time)
          return rec.value_at(time)
        end
        return 0
      end

      def round_to_day(time, up)
        return time if (time % ONE_DAY == 0)
        prev = time - (time % ONE_DAY)
        return up ? prev + ONE_DAY : prev
      end

      def get_fraction_of_day(time, from_start)
        frac = (time % ONE_DAY).to_f / ONE_DAY 
        from_start ? frac : 1 - frac 
      end

      def add_one_record(rec)
        #shortcut to reduce runtime.  LEVELS data will never overlap
        if (@tag =~ /LEVEL/) then
          @data.push(rec)
          return
        end
        if (@data.empty?) then
          @data[0] = rec
        else
          @data.each_index do |i|
            next unless rec.overlap(@data[i])
            new_recs = rec.merge(@data[i])
            rec = new_recs.pop
            @data[i] = new_recs
            break if rec.nil?
          end
          @data.push(rec) unless rec.nil?
          @data.flatten!
          @data.sort!
        end
      end
    end

    class FileData
      attr_reader :tags, :org, :item, :unit, :nomenclature
      def initialize(filename)
        @filename = filename
        @data = {}
        @tags = []
        process_file #will set @data and @tags
        if (!@data[REFILL_REQUISITION].nil?) then
          last_requisition = @data[REFILL_REQUISITION].last_day
          @data[REFILL_PROJECTION].delete_before_time(last_requisition)
          @data[REFILL_PROJECTION_RESPONSE].delete_before_time(last_requisition)
        end
      end

      def delta_days
        ddays = []
        @data.each_key do |tag|
          next if tag =~ /LEVELS/
          ddays = ddays | @data[tag].delta_days
        end
        return ddays
      end

      def value_at(tag, time)
        return 0 unless @data.keys.include?(tag)
        return @data[tag].value_at(time)
      end

      def max_value(tag)
        return @data[tag].max_value
      end

      #determines the locations of each field in the XML file based on the current XML tag
      def get_field_info(key)
        info = []
        if key == LEVELS then
          info[0] = {}
          info[1] = {}
          info[2] = {}
            
          info[0]["tag"] = "LEVELS_REORDER"
          info[0]["start time"] = 1
          info[0]["end time"] = 2
          info[0]["data"] = 3
          info[0]["type"] = "levels"
          info[0]["success"] = false
          info[1]["tag"] = "LEVELS_INVENTORY"
          info[1]["start time"] = 1
          info[1]["end time"] = 2
          info[1]["data"] = 4
          info[1]["type"] = "levels"
          info[1]["success"] = false
          info[2]["tag"] = "LEVELS_TARGET"
          info[2]["start time"] = 1
          info[2]["end time"] = 2
          info[2]["data"] = 5
          info[2]["type"] = "levels"
          info[2]["success"] = false

        elsif [REFILL_PROJECTION_RESPONSE, REFILL_REQUISITION_RESPONSE, DEMAND_PROJECTION_RESPONSE, DEMAND_REQUISITION_RESPONSE].include?(key) then
          info[0] = {}
          info[0]["tag"] = key
          info[0]["success"] = 6
          info[0]["start time"] = 7
          info[0]["end time"] = 8
          info[0]["data"] = 9
          info[0]["type"] = (key =~ /PROJECT/) ? "projection" : "requisition"
        elsif  [REFILL_PROJECTION, REFILL_REQUISITION, DEMAND_PROJECTION, DEMAND_REQUISITION].include?(key) then
          info[0] = {}
          info[0]["tag"] = key
          info[0]["success"] = false
          info[0]["start time"] = 5
          info[0]["end time"] = 6
          info[0]["data"] = 7
          info[0]["type"] = (key =~ /PROJECT/) ?  "projection" : "requisition"
        else
          info = nil
        end
        return info
      end

      def process_file
        file = IO.readlines(@filename)
        tag = nil
        tag_info = nil
        readable = false
        last = {}
     
        file.each do |line|
          line.chomp!        

            
          if (line  =~ /<INVENTORY_HEADER_READABLE/) then
            readable = true
            file_info = line.split(/ \w+=/)
            @org = file_info[1]
            @item = file_info[2]
            @unit = file_info[3]
            @nomenclature = file_info[4]
            next
          end

          next if line =~ /<PARENT/            
          next unless readable

          if (line =~ /INVENTORY_HEADER_GUI/) then
            break
          end

          if line[0..1] == "</" then
            tag = info = nil
          elsif line[0..0] == "<" then
            tag = line[1..-2]
            tag = tag.split(/ /)[0]
            tag_info = get_field_info(tag)
            next if tag_info.nil?
            tag_info.each do |info|
              @tags.push(info["tag"])
              @data[info["tag"]] = TagData.new(info["tag"],  info["type"] == "projection")
            end
            last = {}
          else
            next if (tag_info.nil? || tag.nil?)
            fields = line.split(/,/)
            tag_info.each do |info|
              start_time = fields[info["start time"]]
              end_time = fields[info["end time"]]
              data = fields[info["data"]]
              if data.nil? then
                data = last[info["tag"]]
              else
                last[info["tag"]] = data
              end
              success = (info["success"] ? fields[info["success"]] : "SUCCESS")
              start_time = end_time if start_time.size == 0
              @data[info["tag"]].add_record(start_time, end_time, data) if success == "SUCCESS"
            end
          end
        end
      end
    end

    class FileVerifier
      def initialize(subject_file, benchmark_file, abs_tol, rel_tol)
        @subject_file = subject_file
        @benchmark_file = benchmark_file
        @subject_data = FileData.new(subject_file)
        @benchmark_data = FileData.new(benchmark_file)
        @days = (@subject_data.delta_days() | @benchmark_data.delta_days()).sort
        @tolerance = {}
        @benchmark_data.tags.each  do |tag|
            @tolerance[tag] = @benchmark_data.max_value(tag)*rel_tol + abs_tol
        end
      end
    
      def verify_headers
        return false unless @subject_data.org == @benchmark_data.org
        return false unless @subject_data.item == @benchmark_data.item
        return false unless @subject_data.unit == @benchmark_data.unit
        return false unless @subject_data.nomenclature == @benchmark_data.nomenclature
        return true
      end
    
      def verify(skip_demand = false, skip_refill = false, skip_levels = false)
        errors = []
        if (!verify_headers)
          errors.push(InventoryTestCriticalError.new("Headers don't verify for #{@subject_file} and #{@benchmark_file}"))
        end
        
        extra_tags = @benchmark_data.tags - @subject_data.tags
        extra_tags.each do |tag|
          errors.push(InventoryTestCriticalError.new("#{@subject_file} is missing #{tag}"))
        end
        
        @days.each do |day|
          @benchmark_data.tags.each do |tag|
            next if extra_tags.include?(tag)
            next if skip_demand && is_demand(tag)
            next if skip_refill && is_refill(tag)
            next if skip_levels && is_levels(tag)            
            subject_value = @subject_data.value_at(tag, day)
            benchmark_value = @benchmark_data.value_at(tag, day)
            tol = @tolerance[tag]
            if(!verify_value(subject_value, benchmark_value, tol)) then
              errors.push(InventoryTestError.new(day, tag, subject_value, benchmark_value, tol))
            end
          end
        end
        return errors
      end


      #Verifies that valuie is within range of the target
      def verify_value(value, target, tol)
        value = 0 unless value
        target = 0 unless target
        return value.between?(target - tol, target + tol)
      end

      def is_refill(tag)
        return [REFILL_REQUISITION, REFILL_PROJECTION, REFILL_REQUISITION_RESPONSE, 
                REFILL_PROJECTION_RESPONSE].include?(tag)
      end
    
      def is_demand(tag)
        return [DEMAND_REQUISITION, DEMAND_PROJECTION, DEMAND_REQUISITION_RESPONSE, 
                DEMAND_PROJECTION_RESPONSE].include?(tag)
      end
    
      def is_levels(tag)
        return (tag =~ /LEVELS/)
      end
    end

    class VerifyInventory
      def initialize(archive, plugin, ikko)
        @archive = archive
        @plugin = plugin
        @ikko = ikko
      end
      
      def perform(abs_tol, rel_tol)
        data = []
        baseline_name = @archive.group_baseline
        baseline = @archive.open_prior_archive(baseline_name)
        baseline_name = "Missing Baseline" if baseline.nil?
          
        @archive.add_report("INV", @plugin.plugin_configuration.name) do |report|
          inv_files = @archive.files_with_description(/Inventory/).sort{|x, y| x.name <=> y.name}
          if (!baseline.nil?) then
            inv_files.each do |inv_file|
              subject = inv_file.name
              benchmark_pattern = Regexp.new(File.basename(subject))
              benchmark_file = baseline.files_with_name(benchmark_pattern)[0]
              subject =~ /(fcs-)?(ua-)?(Stage.*?)-/
              stage = "#{$1}#{$2}#{$3}"
              if (!benchmark_file.nil?) then
                data << InventoryTestData.new(subject, benchmark_file.name, stage, [], 0)
                data.last.errors = FileVerifier.new(subject, benchmark_file.name, abs_tol, rel_tol).verify
              else
                data << InventoryTestData.new(subject, "MISSING", stage, [], 0)
                data.last.errors = [InventoryTestCriticalError.new("Benchmark not found")]
              end  
            end
          end
          error_level = analyze(data)
          if (error_level == SUCCESS) then
            report.success
          else
            report.failure
          end
          output = html_output(data, baseline_name)
          report.open_file("Inventory.html", "text/html", "Inventory comparison") do |file|
            file.puts output
          end

          output = create_description
          report.open_file("inv_description.html", "text/html", "Inventory comparison description") do |file|
            file.puts output
          end

        end
        baseline.cleanup unless baseline.nil?
      end
       
      def analyze(data)
        error_level = SUCCESS
        data.each do |file_data|
          e = analyze_file(file_data)
          file_data.error_level = e
          error_level = (error_level > e ? error_level : e)
        end
        error_level = FAIL if data.empty?
        return error_level
      end
      
      def analyze_file(file_data)
        return file_data.errors.empty? ? SUCCESS : FAIL
      end
      
      def collect_by_stage(data)
        collection = {}
        data.each do |rec|
          collection[rec.stage] = [] if collection[rec.stage].nil?
          collection[rec.stage] << rec
        end
        return collection
      end


      def html_output(data, baseline)
	data_by_stage = collect_by_stage(data)
        ikko_hash = {}
        ikko_hash["id"] = @archive.base_name
        ikko_hash["baseline"] = baseline
        ikko_hash["description_link"] = "inv_description.html"
        table_string = ""
        row = 0        
 
        data_by_stage.keys.sort.each do |stage|
          row_string = @ikko["header_template.html", {"data"=>stage,}]
          table_string << @ikko["row_template.html", {"data"=>row_string, "options"=>"BGCOLOR=#888888"}]
          row += 1
          data_by_stage[stage].each do |agent| 
            row_string = ""
            if (agent.error_level == SUCCESS) then
              row_string << @ikko["cell_template.html", {"data"=>File.basename(agent.subject_file), "options"=>"BGCOLOR=#00DD00"}]
              table_string << @ikko["row_template.html", {"data"=>row_string}]
            else
              table_string << error_html(agent, row)
            end
            row += 1
          end
        end 
        ikko_hash["table"] = table_string
        return @ikko["inv_report.html", ikko_hash]
      end

      def error_html(agent, row)
        error_string = ""
        row_string = @ikko["cell_template.html", {"data"=>agent.subject_file.split(/\//).last.split(/\./)[0], "options"=>"ROWSPAN=5 BGCOLOR=#FF0000"}]
        1.upto 5 do |i|
           col = 0
           agent.errors.each do |error|
             row_string << error_row_html(error, i, col, row)
             col += 1
           end
          error_string << @ikko["row_template.html", {"data"=>row_string}]
          row_string = ""
        end
        return error_string
      end

      def error_row_html(error, index, col, row)
        color = nil
        data = nil
        if error.class.to_s =~ /Critical/ then
          color = "BGCOLOR=#FF0000"
        elsif (col + row) % 2 == 0 then
          color = "BGCOLOR=#BBBBBB"
        else
          color = "BGCOLOR=#DDDDDD"
        end
                
        if error.class.to_s =~ /Critical/ then
          if (index == 1) then
            data = "Critical error"
          elsif (index == 2) then
            data = error.msg
          else
            data = "&nbsp;"
          end
        else
          if (index == 1) then
            data = "Day:  #{error.day}"
          elsif(index == 2) then
            data = "Tag:  #{error.tag}"
          elsif(index == 3) then
            data = "Subject:  #{error.subject_value}"
          elsif(index == 4) then
            data = "Benchmark:  #{error.benchmark_value}"
          else
            data = "Tolerance:  #{error.tolerance}"
          end
        end
        return @ikko["cell_template.html", {"data"=>data, "options"=>color}]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Inventory Report"
        ikko_data["title"] = "Inventory Report Description"
        ikko_data["description"] = "Verifies the inventory files with the inventory files of a baseline run."
        ikko_data["description"] << "Each file is compared with the corresponding baseline file on all dates"
        ikko_data["description"] << "where the inventory levels change.  If the subject and baseline are not"
        ikko_data["description"] << " within 10% of each other there is an error.  Critical errors occur if the"
        ikko_data["description"] << " baseline cannot be found or if there are missing or extraneous xml tags."
        success_table = {"success"=>"Every file is within 10% of the baseline file for every date tested",
                         "partial"=>"not used",
                         "fail"=>"At least one error or critical error."}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
   end
  end
end

