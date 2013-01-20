# -*- coding: utf-8 -*-
require_relative "helpers"

class MapTest < Test::Unit::TestCase
  include OpenRubyRMK::Backend
  include OpenRubyRMK::Backend::Fixtures
  include OpenRubyRMK::Backend::AdditionalAssertions

  def setup
    @map = Map.new(1)
  end

  def test_format_filename
    assert_equal("0001.tmx", Map.format_filename(1))
    assert_equal("0010.tmx", Map.format_filename(10))
    assert_equal("0100.tmx", Map.format_filename(100))
    assert_equal("1000.tmx", Map.format_filename(1000))
    assert_equal("1111.tmx", Map.format_filename(1111))
    # Extremely large number probably never used
    assert_equal("10000.tmx", Map.format_filename(10000))
  end

  def test_map_creation
    assert_empty(@map.children)
    assert_nil(@map.parent)
    assert("Map_0001", @map[:name])
    assert(@map.tmx_map, "Didn't assign a TMX map to a new map")
    assert_equal(Map::DEFAULT_MAP_WIDTH, @map.tmx_map.width)
    assert_equal(Map::DEFAULT_MAP_HEIGHT, @map.tmx_map.height)
    assert_equal(Map::DEFAULT_TILE_EDGE, @map.tmx_map.tilewidth)
    assert_equal(Map::DEFAULT_TILE_EDGE, @map.tmx_map.tileheight)
    assert_equal(1, @map.tmx_map.layers.count)
    assert_equal(Map::DEFAULT_MAP_WIDTH * Map::DEFAULT_MAP_HEIGHT,
                 @map.tmx_map.get_layer(-1).map.width * @map.tmx_map.get_layer(-1).map.height)
    assert_equal(Map::DEFAULT_LAYER_COMPRESSION, @map.tmx_map.get_layer(-1).compression)
    assert_equal(Map::DEFAULT_LAYER_ENCODING, @map.tmx_map.get_layer(-1).encoding)
    assert(@map.root?, "Didn't reconise a map without a parent as a root map.")
  end

  def map_properties
    @map[:foobar] = 33
    assert_equal("33", @map[:foobar])
    assert_equal("33", @map["foobar"])
    @map["baz"] = "abc"
    assert_equal("abc", @map[:baz])
    assert_equal("abc", @map["baz"])
  end

  def test_children
    # root_map
    #   |
    # child_map
    root_map         = Map.new(1)
    child_map        = Map.new(11)
    child_map.parent = root_map

    # Test root and child map know one another
    assert_equal(1, root_map.children.count)
    assert_equal(root_map, child_map.parent)
    assert_empty(child_map.children)
    assert(root_map.has_child?(child_map),    "Child not recognised!")
    assert(root_map.has_child?(child_map.id), "Child ID not recognised!")

    # root_map
    #   |
    # child_map
    #   |
    # grandchild_map
    grandchild_map = Map.new(111)
    grandchild_map.parent = child_map

    # Check who knows whom
    refute(root_map.has_child?(grandchild_map),  "Grandchild recognised!")
    assert(child_map.has_child?(grandchild_map), "Child not recognised!")
    assert(root_map.ancestor?(grandchild_map),   "Didn't recognise itself as an ancestor of a grandchild!")

    # root_map
    #   |
    # child_map
    #   |
    # grandchild_map
    #   |
    # grandgrandchild_map
    grandgrandchild_map = Map.new(1111)
    grandgrandchild_map.parent = grandchild_map

    # Delete child_map, preserving the children:
    #
    # root_map
    #   |
    # grandchild_map
    #   |
    # grandgrandchild_map
    grandchild_map.parent = root_map
    child_map.unmount
    assert_equal(1, root_map.children.count)
    assert_equal(grandchild_map, root_map.children.first)
    assert_equal(root_map, grandchild_map.parent)

    # Now delete grandchild_map plus children.
    #
    # root_map
    #   |
    # (nothing)
    grandchild_map.unmount
    assert_empty(root_map.children)
  end

  def test_reparenting
    # root_map
    #    |
    #    +-------------+
    #    |             |
    # child_map   child2_map
    root_map   = Map.new(1)
    child_map  = Map.new(11)
    child2_map = Map.new(12)
    child_map.parent  = root_map
    child2_map.parent = root_map
    assert_equal(2, root_map.children.count)

    # root_map
    #   |
    # child2_map
    #   |
    # child_map
    child_map.parent = child2_map
    assert_equal(1, child2_map.children.count)
    assert_equal(1, root_map.children.count)
    assert_equal(child2_map, root_map.children.first)
    assert_equal(child2_map, child_map.parent)
    assert_equal(child_map, child2_map.children.first)
    assert_equal(root_map, child_map.parent.parent)
  end

  def test_adding_tilesets_and_gids
    tileset = TiledTmx::Tileset.load_xml(fixture("resources/gimp.tsx")) # 144 tiles
    event_emitted = false

    assert_equal(1, @map.tmx_map.next_first_gid)
    @map.observe(:tileset_added) do |event, sender, hsh|
      unless event_emitted # Only for the first adding, see below
        assert_equal(tileset, hsh[:tileset])
        assert_equal(1, hsh[:gid])
      end

      event_emitted = true
    end
    @map.add_tileset(tileset)

    assert(event_emitted, "No tileset addition event was issued")
    assert_equal(145, @map.tmx_map.next_first_gid) # 144 tiles
    assert_equal(1, @map.tmx_map.tilesets.count)
    assert_equal(1, @map.tmx_map.each_tileset_key.first)
    assert_equal(tileset, @map.tmx_map.each_tileset.first[1])

    @map.add_tileset(tileset)
    assert_equal(289, @map.tmx_map.next_first_gid)
  end

  def test_adding_layers
    assert_equal(1, @map.tmx_map.layers.count)

    event_fired = false
    @map.observe(:layer_added) do |event, sender, info|
      event_fired = true
      assert_kind_of(TiledTmx::Layer, info[:layer])
    end

    @map.add_layer(:tile, :name => "A new layer")
    assert(event_fired, "No layer addition event was issued")
    assert_equal(2, @map.tmx_map.layers.count)
    assert_equal("A new layer", @map.tmx_map.get_layer(-1).name)

    event_fired = false
    layer = TiledTmx::TileLayer.new(@map.tmx_map, :name => "Another layer")
    @map.add_layer(layer)
    assert(event_fired, "No layer addition event was issued")
    assert_equal(3, @map.tmx_map.layers.count)
    assert_equal("Another layer", @map.tmx_map.get_layer(-1).name)
    assert_equal(layer, @map.tmx_map.get_layer(-1))
  end

  def test_saving
    Dir.mktmpdir do |tmpdir|
      tmpdir = Pathname.new(tmpdir)

      map1 = Map.new(1)
      map1.save(tmpdir)
      assert_file(tmpdir + "0001.tmx")

      map2 = Map.from_file(tmpdir + "0001.tmx")
      assert_equal(1, map2.id)
      assert_equal(map1, map2)
    end
  end

end
