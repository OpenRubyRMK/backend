#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# start.rb - OpenRubyRMK game startup file.
# This is the first file executed when a game
# starts up.

# Require our standard library dependencies.
require "bundler"
require "pathname"

# Require our non-standard dependencies from the Gemfile.
Bundler.require(:default)

# Find the project root, i.e. the directory
# one level above this very file.
root = Pathname.new(__FILE__).dirname.parent.expand_path

# Start the game, and if it crashes, dump out an error
# report.
begin
  engine = OpenRubyRMK::Engine.new(ARGV, root)
  engine.start!
rescue => e
  crashlog = root + "crashdump.log"
  crashlog.open("w") do |file|
    file.puts("OpenRubyRMK game crashdump from #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
    file.puts(RUBY_DESCRIPTION)
    #file.puts("Engine version is #{OpenRubyRMK::Engine.version}.") # Not yet implemented
    file.puts
    file.puts("#{e.class.name}: #{e.message}")
    file.puts(e.backtrace.join("\n\t"))
  end

  # Reraise and crash
  $stderr.puts
  $stderr.puts("-" * 80)
  $stderr.puts '"It is an incident again, Captain, is it?"'
  $stderr.puts '"No, professor. This is an accident, no incident."'
  # TODO: Actually research that quote in my library. I’ve
  # recalled it from memory.

  $stderr.puts
  $stderr.puts("Crashdump is here: #{crashlog}")
  $stderr.puts("If you think you found a bug, please report it at http://pegasus-alpha.eu/projects/openrubyrmk.")
  $stderr.puts
  raise
end
