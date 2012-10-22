# -*- ruby -*-
gem "rdoc"
require "rake"
require "rake/clean"
require "rubygems/package_task"

CLOBBER.include("doc")

load "openrubyrmk-backend.gemspec"
Gem::PackageTask.new(GEMSPEC).define
