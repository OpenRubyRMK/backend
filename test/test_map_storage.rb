# -*- coding: utf-8 -*-
require_relative "helpers"

class MapStorageTest < Test::Unit::TestCase
  include OpenRubyRMK::Backend
  include OpenRubyRMK::Backend::AdditionalAssertions

  def setup
    @tmpdir    = Pathname.new(Dir.mktmpdir)
    @maps_file = @tmpdir + "maps.xml"
  end

  # Helper for creating a map tree structure; doesn’t
  # write it out to disk. Sets @root to the root of
  # the created hierarchy.
  def create_maps_tree
    # map1
    #  |
    # map2-------+
    #  |         |
    # map3      map4
    @root       = Map.new(1)
    map2        = Map.new(2)
    map3        = Map.new(3)
    map4        = Map.new(4)
    map2.parent = @root
    map3.parent = map2
    map4.parent = map2

  end

  def teardown
    @tmpdir.rmtree
  end

  def test_save_maps_tree
    create_maps_tree

    MapStorage.save_maps_tree(@tmpdir, @maps_file, @root)
    assert_file(@tmpdir + "maps.xml")

    xml = Nokogiri::XML(File.open(@maps_file))
    assert_equal("maps", xml.root.name)
    assert_equal(4, xml.xpath("//map").count)
    assert_equal(1, xml.root.xpath("map").count)
    assert_equal(2, xml.root.xpath("map/map").first.xpath("map").count)
  end

  def test_load_maps_tree
    create_maps_tree
    MapStorage.save_maps_tree(@tmpdir, @maps_file, @root)

    maps = MapStorage.load_maps_tree(@tmpdir, @maps_file)
    assert_equal(1, maps.count)

    root =  maps.first
    map1 = root.children.first
    map2 = root.children.first.children.first
    map3 = root.children.first.children.last

    assert_equal(1, root.children.count)
    assert_equal(2, map1.children.count)
    assert_equal(root, map1.parent)
    assert_equal(map1, map2.parent)
    assert_equal(map1, map3.parent)
  end

  def test_invalid_map_ids
    create_maps_tree
    dup = Map.new(2)
    dup.parent = @root.children.first

    assert_raises(OpenRubyRMK::Backend::Errors::DuplicateMapID){MapStorage.save_maps_tree(@tmpdir, @maps_file, @root)}
  end
end
