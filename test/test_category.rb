# -*- coding: utf-8 -*-
require_relative "helpers"

class CategoryTest < Test::Unit::TestCase
  include OpenRubyRMK::Backend

  def test_creation
    cat = Category.new("stuff")
    assert_equal("stuff", cat.name)
    assert_empty(cat.each_attribute.to_a)
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

    item = { :name => "Hot thing",
    :type => "fire" }
    items << item

    Dir.mktmpdir do |tmpdir|
      path = items.save(tmpdir)

      # Read it back in
      items = Category.from_file(path)
      assert_equal(2, items.count)
      assert_equal("Cool thing", items.entries.first[:name])
      assert_equal("fire", items.entries.last[:type])
    end
  end

  def test_add_and_delete_attributes
    cat = Category.new("stuff")
    cat.add_attribute("name")
    cat.add_attribute("usability")
    
    assert_equal(2, cat.each_attribute.count)
    assert_includes(cat.each_attribute.to_a, "name")
    assert_includes(cat.each_attribute.to_a, "usability")
    
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
    refute_includes(cat.each_attribute.to_a, "usability")
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
    assert_nothing_raised(Category::UnknownAttribute){entry["baz"] = "foobar"}
    assert_equal("foobar", entry[:baz])

    # This snippet adds an invalid attribute *after* the
    # entry has already been added to a category. This
    # ensures validation of an entry not only happens
    # in the Category#<< method.
    entry = Category::Entry.new(:baz => "blubb")
    cat << entry
    assert_raises(Category::UnknownAttribute){entry[:nonexistant] = "fuuuuuu"}
    
    # Deleteing an entry from its category
    # disables the validation again.
    cat.delete(entry)
    assert_nothing_raised(Category::UnknownAttribute){entry[:nonexistant] = "fuuuuuu"}
  end

  def test_move_entries
    cat1 = Category.new("stuff")
    cat1.add_attribute("foo")

    cat2 = Category.new("stuff")
    cat2.add_attribute("bar")
    
    entry = Category::Entry.new
    entry[:foo] = "Bar"
    cat1 << entry
    assert_equal(1, cat1.count)
    assert_equal(0, cat2.count)
    assert_equal("Bar", entry[:foo])
    
    assert_raises(Category::UnknownAttribute){cat2 << entry}
    entry.delete(:foo)
    assert_nothing_raised(Category::UnknownAttribute){cat2 << entry}
    
    assert_equal(0, cat1.count)
    assert_equal(1, cat2.count)
    assert_equal("", entry[:bar])
  end
  
end
