# -*- coding: utf-8 -*-
require_relative "helpers"

class PropertiesTest < Test::Unit::TestCase
  include OpenRubyRMK
  include OpenRubyRMK::Backend
  include OpenRubyRMK::Backend::AdditionalAssertions

  class Thing
    extend OpenRubyRMK::Backend::Properties

    property :foo
    property :bar, :default => 33
  end

  def test_property
    t = Thing.new
    assert_nil t.foo

    t.foo :foo
    assert_equal :foo, t.foo

    t.foo = :bar
    assert_equal :bar, t.foo

    assert_raise(ArgumentError){t.foo(1, 2)}
  end

  def test_property_defaults
    t = Thing.new
    assert_nil t.foo
    assert_equal 33, t.bar

    t.bar "test"
    assert_equal "test", t.bar

    t.bar = /ff/
    assert_equal /ff/, t.bar

    assert_raise(ArgumentError){t.bar(1, 2)}
  end

  def test_properties
    assert_equal [:foo, :bar], Thing.properties
  end

end
