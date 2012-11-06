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

  # Asserts that +obj+ answers +true+ to <tt>frozen?</tt>.
  # You  may specify an alternate failure message.
  def assert_frozen(obj, msg = nil)
    assert(obj.frozen?, msg || "Object not frozen: #{obj.inspect}")
  end

end

# Some helper methods for accessing test fixtures,
# i.e. test stub data.
module OpenRubyRMK::Backend::Fixtures

  # Directory where the fixtures reside in. A
  # Pathname instance.
  def fixtures_dir
    Pathname.new(__FILE__).dirname + "fixtures"
  end

  # Tries to locate the fixture named +name+ and returns
  # a Pathname to it. Raises a RuntimeError if the fixture
  # cannot be found.
  def fixture(name)
    target = fixtures_dir + name
    raise("Test fixture not found: #{target}") unless target.file?

    target
  end

end
