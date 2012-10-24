# -*- coding: utf-8 -*-
require_relative "helpers"

class CategoryTest < Test::Unit::TestCase
  include OpenRubyRMK::Backend

  def test_creation
    cat = Category.new("stuff")
    assert_equal("stuff", cat.name)
    assert_empty(cat.allowed_attributes)
    assert_empty(cat.entries)
  end

  def test_from_and_to_xml
    items = Category.new("items")
    items.add_attribute("name")
    items.add_attribute("type")

    item = Category::Entry.new
    item[:name] = "Cool thing"
    item[:type] = "ice"
    items << item

    item = Category::Entry.new
    item[:name] = "Hot thing"
    item[:type] = "fire"
    items << item

    Dir.mktmpdir do |tmpdir|
      path = items.save(tmpdir)

      # Read it back in
      items = Category.from_file(path)
      assert_equal(2, items.entries.count)
      assert_equal("Cool thing", items.entries.first[:name])
      assert_equal("fire", items.entries.last[:type])
    end
  end

  def test_add_and_delete_attributes
    cat = Category.new("stuff")
    cat.add_attribute("name")
    cat.add_attribute("usability")

    assert_equal(2, cat.allowed_attributes.count)
    assert_includes(cat.allowed_attributes, "name")
    assert_includes(cat.allowed_attributes, "usability")
    
    item = Category::Entry.new
    item[:name] = "Foo"
    item[:usability] = "Bar"
    cat << item
    cat.add_attribute("grade_of_nonsense")
    assert_equal("", item[:grade_of_nonsense])

    item = Category::Entry.new
    item[:grade_of_nonsense] = "100%"
    cat.delete_attribute(:grade_of_nonsense)
    assert_raises(Category::UnknownAttribute){cat << item}

    cat.delete_attribute("usability")
    refute_includes(cat.allowed_attributes, "usability")
    refute(item.include?(:usability), "Didn't delete `usability' attribute.")
    assert_equal("", item[:usability]) # Nonexistant attributes should return an empty string
  end

  def test_entries
    cat = Category.new("stuff")
    cat.add_attribute("foo")
    cat.add_attribute("bar")

    entry = Category::Entry.new
    entry["foo"] = "Bar"
    cat << entry

    assert_includes(cat.entries, entry)
    assert_equal("Bar", entry[:foo])
    assert_equal("Bar", entry["foo"])

    entry = Category::Entry.new(:foo => "bar")
    assert_equal("bar", entry[:foo])
    assert_equal("bar", entry["foo"])

    entry = Category::Entry.new(:baz => "blubb")
    assert_raises(Category::UnknownAttribute){cat << entry}

    # Add an entry AFTER the call to Entry#initialize has
    # happened, i.e. the entry has no information that
    # we have a new attribute yet. It has to consult the
    # Category object again.
    cat.add_attribute("baz")
    entry["baz"] = "foobar" # Should not error out with UnknownAttribute anymore
    assert_equal("foobar", entry[:baz])

    # This snippet adds an invalid attribute *after* the
    # entry has already been added to a category. This
    # ensures validation of an entry not only happens
    # in the Category#<< method.
    entry = Category::Entry.new(:baz => "blubb")
    cat << entry
    assert_raises(RuntimeError){entry[:nonexistant] = "fuuuuuu"}
  end

end
