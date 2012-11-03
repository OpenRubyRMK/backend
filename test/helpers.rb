# -*- coding: utf-8 -*-
require "test/unit"
require "tempfile"
require "turn/autorun"

require_relative "../lib/open_ruby_rmk/backend"

# Defines extra assertions to be used in unit tests.
module OpenRubyRMK::Backend::AdditionalAssertions

  # Asserts that +path+, which may either be a Pathname
  # or a String, is a directory. You may specify an
  # alternate failure message.
  def assert_dir(path, msg = nil)
    assert(File.directory?(path), msg || "Not a directory: #{path}")
  end

  # Asserts that +path+, which may either be a Pathname
  # or a String, is a file. You may specify an alternate
  # failure message.
  def assert_file(path, msg = nil)
    assert(File.file?(path), msg || "Not a file: #{path}")
  end

  # Asserts that +path+, which may either be a Pathname
  # or a String, doesn’t exist on the filesystem. You may
  # specify an alternate failure message.
  def refute_exists(path, msg = nil)
    assert(!File.exists?(path), msg || "File exists: #{path}")
  end

end
