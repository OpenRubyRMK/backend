# -*- coding: utf-8 -*-
require_relative "helpers"

class CategoryTest < Test::Unit::TestCase
  include OpenRubyRMK::Backend

  def test_empty_creation
    cat = Category.new("stuff")

    assert_equal("stuff", cat.name)
    assert_empty(cat.allowed_attributes)
    assert_empty(cat.entries)
  end

  def test_creation_with_block_parameter
    cat = Category.new("stuff") do |c|
      c.define_attribute :name, :string, "The name"
      c.define_attribute :type, :ident, "The type"
      c.define_attribute :damage, :float, "The damage"
    end

    assert_equal("stuff", cat.name)
    assert_includes(cat.allowed_attributes, :name)
    assert_includes(cat.allowed_attributes, :type)
    assert_includes(cat.allowed_attributes, :damage)
  end

  def test_from_and_to_xml
    items = Category.new("items")
    items.define_attribute :name, :string, "The name"
    items.define_attribute :type, :ident, "The type", :choices => [:ice, :earth, :fire]
    items.define_attribute :grade_of_nonsense, :number, "?!", :minimum => 10, :maximum => 20

    item = Category::Entry.new
    item[:name] = "Cool thing"
    item[:type] = :ice
    item[:grade_of_nonsense] = 12
    items << item

    item = { :name => "Hot thing",
    :type => :fire }
    items << item

    assert_equal 2, items.count

    Dir.mktmpdir do |tmpdir|
      path = items.save(tmpdir)

      # Read it back in
      items = Category.from_file(path)
      assert_equal(2, items.count)

      assert_includes(items.allowed_attributes.keys, :name)
      assert_includes(items.allowed_attributes.keys, :type)
      assert_includes(items.allowed_attributes.keys, :grade_of_nonsense)

      assert_equal(10, items.allowed_attributes[:grade_of_nonsense].minimum)
      assert_equal(20, items.allowed_attributes[:grade_of_nonsense].maximum)
      assert_includes(items.allowed_attributes[:type].choices, :ice)
      assert_includes(items.allowed_attributes[:type].choices, :earth)
      assert_includes(items.allowed_attributes[:type].choices, :fire)
      assert_equal(:string, items.allowed_attributes[:name].type)
      assert_equal(:ident, items.allowed_attributes[:type].type)

      assert_equal("Cool thing", items.entries.first[:name])
      assert_equal(:fire, items.entries.last[:type]) # Note this has done type conversion from the XML-stored string!
      assert_equal(12, items.entries.first[:grade_of_nonsense])
    end
  end

  def test_add_and_remove_attributes
    cat = Category.new("stuff")
    cat.define_attribute :name, :string, "The name of the thing"
    cat.define_attribute :usability, :ident, "How to use it"

    assert_equal(2, cat.allowed_attributes.count)
    assert_includes(cat.allowed_attributes, :name)
    assert_includes(cat.allowed_attributes, :usability)

    item = Category::Entry.new
    item[:name] = "Foo"
    item[:usability] = :bar
    cat << item
    cat.define_attribute :grade_of_nonsense, :float, "What?!"
    assert_nil(item[:grade_of_nonsense])

    item = Category::Entry.new
    item[:grade_of_nonsense] = 100.0
    cat.remove_attribute(:grade_of_nonsense)
    assert_raises(OpenRubyRMK::Backend::Errors::UnknownAttribute){cat << item}

    cat.remove_attribute(:usability)
    refute_includes(cat.allowed_attributes, :usability)
    refute(item.include?(:usability), "Didn't delete :usability attribute.")
    assert_nil(item[:usability])
  end

  def test_attribute_details
    cat = Category.new("stuff")
    cat.define_attribute :name, :string, "The name of the thing"
    cat.define_attribute :type, :ident, "The type of the thing"
    cat.define_attribute :importance, :float, "The importance"

    assert_equal :string, cat.allowed_attributes[:name].type
    assert_equal :ident, cat.allowed_attributes[:type].type
    assert_equal :float, cat.allowed_attributes[:importance].type

    assert_equal "The name of the thing", cat.allowed_attributes[:name].description
    assert_equal "The type of the thing", cat.allowed_attributes[:type].description
    assert_equal "The importance", cat.allowed_attributes[:importance].description
  end

  def test_entries
    cat = Category.new("stuff")
    cat.define_attribute :foo, :string, "Foo stuff"
    cat.define_attribute :bar, :ident, "Bar stuff"

    entry = Category::Entry.new
    entry[:foo] = "Bar"
    cat << entry

    assert_includes(cat.entries, entry)
    assert_equal("Bar", entry[:foo])

    entry = Category::Entry.new(:foo => "bar")
    assert_equal("bar", entry[:foo])

    entry = Category::Entry.new(:baz => :blubb)
    assert_raises(OpenRubyRMK::Backend::Errors::UnknownAttribute){cat << entry}

    # Add an entry AFTER the call to Entry#initialize has
    # happened, i.e. the entry has no information that
    # we have a new attribute yet. It has to consult the
    # Category object again.
    cat.define_attribute :baz, :string, "Baz stuff"
    assert_nothing_raised(OpenRubyRMK::Backend::Errors::UnknownAttribute){entry[:baz] = "foobar"}
    assert_equal("foobar", entry[:baz])

    # This snippet adds an invalid attribute *after* the
    # entry has already been added to a category. This
    # ensures validation of an entry not only happens
    # in the Category#<< method.
    entry = Category::Entry.new(:baz => "blubb")
    cat << entry
    assert_raises(OpenRubyRMK::Backend::Errors::UnknownAttribute){entry[:nonexistant] = "fuuuuuu"}

    # Deleteing an entry from its category
    # disables the validation again.
    cat.delete(entry)
    assert_nothing_raised(OpenRubyRMK::Backend::Errors::UnknownAttribute){entry[:nonexistant] = "fuuuuuu"}
  end

  def test_move_entries
    cat1 = Category.new("stuff")
    cat1.define_attribute :foo, :string, "Foo stuff"

    cat2 = Category.new("stuff")
    cat2.define_attribute :bar, :string, "Bar stuff"

    entry = Category::Entry.new
    entry[:foo] = "Bar"
    cat1 << entry
    assert_equal(1, cat1.count)
    assert_equal(0, cat2.count)
    assert_equal("Bar", entry[:foo])

    assert_raises(OpenRubyRMK::Backend::Errors::UnknownAttribute){cat2 << entry}
    entry.delete(:foo)
    assert_nothing_raised(OpenRubyRMK::Backend::Errors::UnknownAttribute){cat2 << entry}

    assert_equal(0, cat1.count)
    assert_equal(1, cat2.count)
    assert_nil(entry[:bar])
  end

  def test_escape_filenames
    assert_equal "Bären", Category.escape_filename("Bären")
    assert_equal "ASCII", Category.escape_filename("ASCII")
    assert_equal "GutBöse", Category.escape_filename("Gut/Böse")
    assert_equal "BackSlash", Category.escape_filename("Back\\Slash")
    assert_equal "No_Space", Category.escape_filename("No Space")
    assert_equal "No_Unicode_Space", Category.escape_filename("No Unicode Space")
    assert_equal "NoPunctuation", Category.escape_filename(".No;Punct%uat:ion?!")
  end

  def test_definitions_access
    cat = Category.new("stuff")
    assert_empty cat.attribute_names

    cat.define_attribute :foo, :ident, "Foo"
    cat.define_attribute :bar, :number, "Bar"

    assert_includes cat.attribute_names, :foo
    assert_includes cat.attribute_names, :bar
    assert_equal cat.allowed_attributes.keys.sort, cat.attribute_names.sort

    assert_equal :ident, cat[:foo].type
    assert_equal "Foo", cat[:foo].description
    assert_equal :number, cat.get_definition(:bar).type
    assert_equal "Bar", cat.get_definition(:bar).description
  end

  def test_minimum_and_maximum
    cat = Category.new("stuff")
    cat.define_attribute :foo, :number, "Foo", :minimum => 0, :maximum => 100
    cat.define_attribute :bar, :float, "Bar", :minimum => -3.2, :maximum => 2.6

    assert_raises(Errors::InvalidEntry){cat << {:foo => -50, :bar => 0}}
    assert_raises(Errors::InvalidEntry){cat << Category::Entry.new(:foo => 5000, :bar => 0)}
    assert_raises(Errors::InvalidEntry){cat << {:foo => 50, :bar => -100}}
    assert_raises(Errors::InvalidEntry){cat << Category::Entry.new(:foo => 50, :bar => -100)}
  end

  def test_choices
    flunk "Please write a test for validating choices on attribute definitions!"
  end

end
