module ACME
  module Plugins
    class CacheManager
      def initialize(cache_dir)
        @cache_dir = (cache_dir.nil? ? "." : cache_dir)
      end
  

      #loads an object from a cached file if it exists
      #if it does not exist attempts to create the object from a block
      #if an object is created this way it is written to the cache
      def load(archive_name, klass) 
        filename = "#{archive_name}-#{klass.name}"
        if File.exist?(File.join(@cache_dir, filename)) then
          puts "loading from cache:  #{filename}"
          return Marshal.load(File.new(File.join(@cache_dir, filename)))
        else
          puts "creating new object:  #{filename}"
          obj = yield(archive_name)
          write(obj, archive_name) if (obj.class == klass) #write only if we got object of the right type
          return obj
        end
      end

      #Writes an object to a cache file associated with the given archive
      def write(obj, archive_name)
        filename = "#{archive_name}-#{obj.class.name}"
        File.open(File.join(@cache_dir, filename), "w") do |out|
          Marshal.dump(obj, out)
        end
      end

      #Prunes the cache by deleting the oldest files if the size of the cache in bytes is greater than max
      def prune(max)
        old = Dir.pwd
        Dir.chdir(@cache_dir)
        files = Dir["*-*"].sort{|x, y| File.ctime(x) <=> File.ctime(y)}
        size = 0
        files.each do |file|
          size += File.size(file)
        end

        while (size > max && !files.empty?)
          size -= File.size(files[0])
          puts "Pruning #{files[0]}"
          File.delete(files[0])
        end
        Dir.chdir(old)
      end
    end
  end
end