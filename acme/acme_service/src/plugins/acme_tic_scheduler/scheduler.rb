module ACME; module Plugins

  class TICScheduler
    extend FreeBASE::StandardPlugin
    
    def self.load(plugin)
      begin
        require 'ikko'
        require 'yaml'
        plugin.transition(FreeBASE::LOADED)
        puts $!
        puts $!.backtrace.join
      rescue
        plugin.transition_failure
      end
    end
    
    def self.start(plugin)
      self.new(plugin)
      plugin.transition(FreeBASE::RUNNING)
    end
    
    attr_reader :plugin
    
    def initialize(plugin)
      @plugin = plugin
      @hostname = `hostname`.strip
      @cougaar_config = plugin['/cougaar/config']
      load_properties
      load_template_engine
      mount_webservices
      start_queue if queue_enabled?
    end
    
    def load_properties
      @experiment_path = @plugin.properties['experiment_path']
      @queue_status = @plugin.properties['queue_status']
      @log = @plugin.properties['log']
      if @log
        @log_file = File.open(@log, File::APPEND|File::CREAT|File::WRONLY) 
        @log_file.sync = true
      end
    end
    
    def enable_queue
      return if @queue_status=="enabled"
      @plugin.properties['queue_status'] = "enabled"
      start_queue
      load_properties
    end
    
    def disable_queue
      return if @queue_status=="disabled"
      @plugin.properties['queue_status'] = "disabled"
      stop_queue
      load_properties
    end
    
    def queue_enabled?
      return @queue_status=='enabled'
    end
    
    def queue_disabled?
      return @queue_status=='disabled'
    end
    
    def start_queue
      return if @queue_thread
      @plugin.log_info << "Starting Scheduling Queue"
      @queue_thread = Thread.new do
        dirpath = File.join(@experiment_path, "experiment-*")
        while(true)
          next_experiment = Dir.glob(dirpath).sort.first
          if next_experiment
            data = File.read(next_experiment)
            File.delete(next_experiment)
            begin
              run_experiment(File.basename(next_experiment), data)
            rescue Exception => e
              @plugin.log_error << "Exception running experiment #{next_experiment}"
              @plugin.log_error <<  e.to_s
              @plugin.log_error <<  e.backtrace.join("\n")
            end
          else
            sleep 5
          end
        end
      end
    end
    
    def stop_queue
      @plugin.log_info << "Stopping Scheduling Queue"
      @queue_thread.kill if @queue_thread
      @queue_thread = nil
    end
    
    def run_experiment(filename, data)
      @plugin.log_info << "Starting new experiment: #{filename}"
      priority, date = parse_filename(filename)
      index = data.index("=begin experiment") 
      eindex = data.index("=end", index)
      return unless eindex
      map = YAML.load(data[(index+18)...eindex])
      @script_dir = File.dirname(replace_cip(map['script']))
      @current = File.join(@script_dir, 'experiment_definition.rb')
      exec_current(data)
      @current = nil
    end
    
    def exec_current(data)
      cmd = @cougaar_config.manager.cmd_wrap("touch #{@current}")
      `#{cmd}`
      cmd = @cougaar_config.manager.cmd_wrap("chmod 777 #{@current}")
      `#{cmd}`
      path_as = File.join(@cougaar_config.manager.cougaar_install_path, "csmart", "acme_scripting", "src", "lib")
      path_redist = File.join(@cougaar_config.manager.cougaar_install_path, "csmart", "acme_service", "src", "redist")
      out_log = File.join(@script_dir, 'scheduledRun.log')
      File.open(@current, 'w') { |f| f.puts(data)}
      cmd = @cougaar_config.manager.cmd_wrap("ruby -W0 -C#{File.dirname(@current)} -I#{path_as} -I#{path_redist} #{@current} >& #{out_log}")
      if @log_file
        @log_file.puts "Starting experiment at #{Time.now}"
        @log_file.puts data
        @log_file.puts "Command: #{cmd}"
      end
      @start_time = Time.now
      result = `#{cmd}`
      out_log_rename = File.join(@script_dir, "scheduledRun-#{Time.now.strftime('%Y%m%d-%H%M%S')}.log")
      rename_cmd = @cougaar_config.manager.cmd_wrap("mv #{out_log} #{out_log_rename}")
      `#{rename_cmd}`
      if @log_file
        run_time = ((Time.now - @start_time)/60).to_i
        @log_file.puts "Finished experiment at #{Time.now}, runtime #{run_time} minutes #{run_time < 5 ? '(Potential Error)' : ''}"
        @log_file.puts "Moved #{out_log} to #{out_log_rename}."
        @log_file.puts "="*60
      end
      cmd = @cougaar_config.manager.cmd_wrap("rm -f #{@current}")
      `#{cmd}`
    end
    
    def replace_cip(script)
      cip = @cougaar_config.manager.cougaar_install_path
      script = script.gsub(/\$CIP/, cip)
      script = script.gsub(/\$COUGAAR_INSTALL_PATH/, cip)
      script
    end
    
    def current
      return "none" unless @current
      @current
    end
    
    def load_template_engine
      @ikko = Ikko::FragmentManager.new
      @ikko.base_path = File.join(@plugin.plugin_configuration.base_path, 'templates')
      @footer = @ikko['schedule_footer.html']
    end
    
    def register_experiment(expt_def, priority)
      filename = "experiment-#{priority}-#{Time.now.to_f}"
      File.open(File.join(@experiment_path, filename), "w") do |file|
        file.puts(expt_def)
      end
      filename
    end

    def parse_filename(filename)
      begin
        p = filename.split("-")[1].to_i
        priority = ["", "high", "medium", "low"][p]
      rescue
        priority = "medium"
      end
      begin
        date = Time.at(filename.split("-")[2].to_f)
      rescue
        date = "unknown"
      end
      return priority, date
    end

    def mount_webservices
      # Mount handler for receiving xml node file via HTTP
      @plugin['/protocols/http/schedule_images'].data = File.join(@plugin.plugin_configuration.base_path, "images")
      @plugin['/protocols/http/schedule_run'].set_proc {|req, res| schedule_run(req, res)} 
      @plugin['/protocols/http/schedule_queue'].set_proc {|req, res| schedule_queue(req, res)}
      @plugin['/protocols/http/schedule_view_current'].set_proc {|req, res| schedule_view_current(req, res)}
    end
    
    def schedule_run(request, response)
      if request.request_method=="POST"
        data = request.query
        text = data['definition_file']
        priority = data['priority']
        priority = '2' unless priority == '1' || priority=='2' || priority=='3'
        text = data['definition_text'] unless text
        filename = register_experiment(text, priority)
        response['Content-Type'] = "text/html"
        response.body = @ikko["schedule_complete.html", {'filename'=>filename, 'footer'=>@footer}]
      else
        response['Content-Type'] = "text/html"
        response.body = @ikko["schedule_run.html", {'footer'=>@footer}]
      end
    end
    
    def schedule_view_current(request, response)
      response['Content-Type'] = "text/html"
      data = File.read(@current)
      experiment = /^name:\s(.*)/.match(data)[1]
      definition = "\n"+data[0, data.index("=end")+5]
      rest = data[data.index("=end")+5..-1]
      response.body = @ikko["run_view.html", 
        {"experiment"=>experiment, "definition"=>definition, "rest"=>rest, 'footer'=>@footer}]
    end
    
    def schedule_queue(request, response)
      if request.request_method=="POST"
        data = request.query
        status = data['status']
        disable_queue if status=='disabled'
        enable_queue if status=='enabled'
      end
      
      response['Content-Type'] = "text/html"
      action = request.query['action']
      if action=="view"
        filename = request.query['run']
        data = File.read(File.join(@experiment_path, filename))
        experiment = /^name:\s(.*)/.match(data)[1]
        definition = "\n"+data[0, data.index("=end")+5]
        rest = data[data.index("=end")+5..-1]
        response.body = @ikko["run_view.html", 
          {"experiment"=>experiment, "definition"=>definition, "rest"=>rest, 'footer'=>@footer}]
      else
        if action=="delete"
          filename = request.query['run']
          if filename
            File.delete(File.join(@experiment_path, filename))
          end
        end
        entries = []
        Dir.glob(File.join(@experiment_path, "experiment-*")).sort.each do |file|
          next if file.include?("README")
          experiment = /^name:\s(.*)/.match(File.read(file))[1]
          filename = File.basename(file)
          priority, date = parse_filename(filename)
          entries << @ikko["schedule_queue_entry.html", 
            {"experiment"=>experiment,
             "filename"=>filename,
             "priority"=>priority,
             "date"=>date
            } ]
        end
        params = { 'footer'=>@footer }
        params['enabled'] = 'checked' if queue_enabled?
        params['disabled'] = 'checked' if queue_disabled?
        params['experiment'] = current
        if @current
          start_time = @start_time ? @start_time.strftime("%m/%d/%y %H:%M:%S") : "unknown"
          run_time = @start_time ? (Time.now - @start_time).to_i/60 : "unknown"
          params['experiment'] = @ikko['schedule_queue_current.html', {'experiment'=>@current, 'start_time'=>start_time, 'run_time'=>run_time}]
        else
          params['experiment'] = "None"
        end
        params['entries'] = entries
        params['hostname'] = @hostname
        response.body = @ikko["schedule_queue.html", params]
      end
    end
    
  end # TICScheduler
      
end ; end 
