# -*- mode: ruby; coding: utf-8 -*-
gem "rdoc"
require "rake"
require "rake/clean"
require "rdoc/task"
require "rubygems/package_task"

ENV["RDOCOPT"] = "" if ENV["RDOCOPT"]
CLOBBER.include("doc")

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
Gem::PackageTask.new(GEMSPEC).define
