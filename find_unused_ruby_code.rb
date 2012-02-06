#!/usr/bin/env ruby
if ARGV.size < 2
  puts "Usage: find_unused_ruby_code \"glob\" rails-app-root-dir"
  puts "Example: find_unused_ruby_code \"app/**/*.rb\" ."
  exit(1)
end

GLOB_PATH = File.expand_path(ARGV[0])
ROOT_DIR = ARGV[1]

RAILS_APP_DIR = File.join(ROOT_DIR, "app")
RAILS_LIB_DIR = File.join(ROOT_DIR, "lib")

require 'rubygems'
require 'ruby_parser'
require 'sexp_path'

total_methods = 0
unused = []

puts GLOB_PATH

Dir[GLOB_PATH].each do |path|

  puts path

  code = File.read(path)
  sexp = Sexp.from_array(ParseTree.new.parse_tree_for_string(code, path))

  class_query = Q?{ s(:class, atom % 'class_name', _, _) }
  method_query = Q?{ s(:defn, atom % 'method_name', _ ) }

  results = sexp / class_query / method_query

  results.each do |sexp_result|
    class_name = sexp_result['class_name']
    method_name = sexp_result['method_name']

    total_methods = total_methods + 1

    used_outside = `grep "#{method_name}" -r #{RAILS_APP_DIR} #{RAILS_LIB_DIR}|grep -v #{path}`.to_s.strip
    if 0 == used_outside.size
      used_inside = `grep "#{method_name}" -r #{path}|wc -l`.to_i
      if 1 == used_inside
        unused << "#{class_name}##{method_name}"
      end
    end

  end

end

puts
puts "Glob: #{GLOB_PATH}"
puts "#{total_methods} methods parsed, #{unused.size} unused"
puts "-" * 80
puts unused
