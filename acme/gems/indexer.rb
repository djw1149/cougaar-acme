#!/usr/bin/env ruby

$:.unshift '~/rubygems'

require 'optparse'
require 'rubygems'
require 'zlib'

Gem.manage_gems

class Indexer

  def initialize(directory)
    @directory = directory
  end

  def gem_file_list
    Dir.glob(File.join(@directory, "*.gem"))
  end

  def build_index
    File.open(File.join(@directory, "yaml"), "w") do |file|
      file.puts "--- !ruby/object:Gem::Cache"
      file.puts "gems:"
      gem_file_list.each do |gemfile|
        spec = Gem::Format.from_file_by_path(gemfile).spec
        file.puts "  #{spec.full_name}: #{spec.to_yaml.gsub(/\n/, "\n    ")[4..-1]}"
      end
      `chmod 644 #{File.join(@directory, "yaml")}`
    end
    build_compressed_index
  end
  
  def build_compressed_index
    File.open(File.join(@directory, "yaml.Z"), "w") do |file|
      file.write(Zlib::Deflate.deflate(File.read(File.join(@directory, "yaml"))))
    end
    `chmod 644 #{File.join(@directory, "yaml.Z")}`
  end
end
