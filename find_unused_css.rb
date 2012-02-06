#!/usr/bin/env ruby
if ARGV.size < 2
  puts "Usage: find_unused_css css-file-name rails-app-root-dir"
  puts "Example: find_unused_css ~/projects/test/public/stylesheets/admin.css ~/projects/test"
  exit(1)
end

SOURCE_FILE = ARGV[0]
ROOT_DIR = ARGV[1]

def find_unused_selectors(parser)
  result = {
    :selectors => [],
    :unused => []
  }

  # Find selectors
  parser.each_selector do |selectors, declarations, specifity|
    result[:selectors] << selectors.split.select{ |selector| yield selector }
  end

  # drop duplicates
  result[:selectors] = result[:selectors].flatten.uniq.sort

  # when a selectors is composed of multiple selectors,
  # we'll pick the rightmost selector and look for it only.
  # example: .listing#clients -> #clients
  #          #reports-datepicker.weekly -> .weekly etc
  result[:selectors] = result[:selectors].map do |selector|
    selector_without_type = selector[1..-1]
    if selector_without_type.include?('.')
      '.' + selector_without_type.reverse.split('.').first.reverse
    elsif selector_without_type.include?('#')
      '#' + selector_without_type.reverse.split('#').first.reverse
    else
      selector
    end
  end

  # ignore selectors that are too complicated :P
  # example: .newbutton[disabled]
  result[:selectors] = result[:selectors].reject{ |selector| selector.include?('[') && selector.include?(']') }

  # grep though code to see if the selector is used at all
  result[:selectors].each do |selector|
    # drop pseudo-selectors
    selector = selector.split(':').first.split('>').first
    found = false
    ['app', 'lib', 'public/javascripts'].each do |location|
      glob = File.join(ROOT_DIR, location, '*')
      grep_result = `grep "#{selector[1..-1]}" #{glob} -r`.to_s.strip
      if grep_result.size > 0
        found = true
        break
      end
    end
    result[:unused] << selector if not found
  end

  result
end

require 'rubygems'
require 'css_parser'
include CssParser

parser = CssParser::Parser.new
parser.load_file!(SOURCE_FILE)

puts ''
classes = find_unused_selectors(parser) { |selector| selector.start_with?('.') }
puts classes[:selectors].size.to_s + " classes found, " + classes[:unused].size.to_s + " unused"
puts classes[:unused]

puts ''
ids     = find_unused_selectors(parser) { |selector| selector.start_with?('#') }
puts ids[:selectors].size.to_s + " ids found, " + ids[:unused].size.to_s + " unused"
puts ids[:unused]
