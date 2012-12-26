#!/usr/bin/env ruby
# start.rb - OpenRubyRMK game startup file.
# This is the first file executed when a game
# starts up.

# Require our dependencies
require "bundler"
require "pathname"
Bundler.require(:default)

# Start the game, and if it crashes, dump out an error
# report.
begin
  engine = OpenRubyRMK::Engine.new(ARGV)
  engine.start!
rescue => e
  path = Pathname.new(__FILE__).dirname.expand_path + "crashdump.log"
  path.open("w") do |file|
    file.puts("OpenRubyRMK game crashdump from #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
    file.puts(RUBY_DESCRIPTION)
    #file.puts("Engine version is #{OpenRubyRMK::Engine.version}.") # Not yet implemented
    file.puts
    file.puts("#{e.class.name}: #{e.message}")
    file.puts(e.backtrace.join("\n\t"))
  end

  # Reraise and crash
  $stderr.puts("==== CRASH ===")
  $stderr.puts("Crash! Error information is below and can also be found in the file #{path}.")
  $stderr.puts("If you think you found a bug, please report it at http://pegasus-alpha.eu/projects/openrubyrmk.")
  $stderr.puts
  raise
end
