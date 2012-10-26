# -*- ruby -*-
gem "rdoc"
require "rake"
require "rake/clean"
require "rubygems/package_task"

CLOBBER.include("doc")

desc "Run the test suite."
task :test do
  cd "test" do
    Dir["test_*.rb"].each do |file|
      load(file)
    end
  end
end

load "openrubyrmk-backend.gemspec"
Gem::PackageTask.new(GEMSPEC).define
