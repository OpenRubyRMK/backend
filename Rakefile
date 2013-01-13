# -*- mode: ruby; coding: utf-8 -*-
gem "rdoc"
require "rake"
require "rake/clean"
require "rdoc/task"
require "rubygems/package_task"

ENV["RDOCOPT"] = "" if ENV["RDOCOPT"]
CLOBBER.include("doc")

desc "Starts up IRB with the backend library loaded."
task :console do
  ARGV.clear # IRB runs havoc otherwise
  require "irb"
  require_relative "lib/open_ruby_rmk/backend"
  puts "Loaded the OpenRubyRMK's backend library, version #{OpenRubyRMK::Backend.version}."
  IRB.start
end

desc "Run the test suite."
task :test do
  cd "test" do
    Dir["test_*.rb"].each do |file|
      load(file)
    end
  end
end

RDoc::Task.new do |rt|
  rt.rdoc_dir = "doc"
  rt.rdoc_files.include("lib/**/*.rb", "**/*.rdoc", "COPYING")
  rt.title = "OpenRubyRMK RDocs ‒ Backend"
  rt.main  = "README.rdoc"
  rt.generator = "emerald"
end

load "openrubyrmk-backend.gemspec"
Gem::PackageTask.new(ORR_BACKEND_GEMSPEC).define
