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
    assert_kind_of(TiledTmx::Map, @map)
    assert("Map_0001", @map[:name])
    assert_equal(Map::DEFAULT_MAP_WIDTH, @map.width)
    assert_equal(Map::DEFAULT_MAP_HEIGHT, @map.height)
    assert_equal(Map::DEFAULT_TILE_EDGE, @map.tilewidth)
    assert_equal(Map::DEFAULT_TILE_EDGE, @map.tileheight)
    assert_equal(1, @map.layers.count)
    assert_equal(Map::DEFAULT_MAP_WIDTH * Map::DEFAULT_MAP_HEIGHT,
                 @map.get_layer(-1).map.width * @map.get_layer(-1).map.height)
    assert_equal(Map::DEFAULT_LAYER_COMPRESSION, @map.get_layer(-1).compression)
    assert_equal(Map::DEFAULT_LAYER_ENCODING, @map.get_layer(-1).encoding)
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

    assert_equal(1, @map.next_first_gid)
    @map.observe(:tileset_added) do |event, sender, hsh|
      unless event_emitted # Only for the first adding, see below
        assert_equal(tileset, hsh[:tileset])
        assert_equal(1, hsh[:gid])
      end

      event_emitted = true
    end
    @map.add_tileset(tileset)

    assert(event_emitted, "No tileset addition event was issued")
    assert_equal(145, @map.next_first_gid) # 144 tiles
    assert_equal(1, @map.tilesets.count)
    assert_equal(1, @map.each_tileset_key.first)
    assert_equal(tileset, @map.each_tileset.first[1])

    @map.add_tileset(tileset)
    assert_equal(289, @map.next_first_gid)
  end

  def test_adding_layers
    assert_equal(1, @map.layers.count)

    event_fired = false
    @map.observe(:layer_added) do |event, sender, info|
      event_fired = true
      assert_kind_of(TiledTmx::Layer, info[:layer])
    end

    @map.add_layer(:tile, :name => "A new layer")
    assert(event_fired, "No layer addition event was issued")
    assert_equal(2, @map.layers.count)
    assert_equal("A new layer", @map.get_layer(-1).name)
    assert_equal(Map::DEFAULT_LAYER_COMPRESSION, @map.get_layer(-1).compression)
    assert_equal(Map::DEFAULT_LAYER_ENCODING, @map.get_layer(-1).encoding)

    event_fired = false
    layer = TiledTmx::TileLayer.new(@map, :name => "Another layer")
    @map.add_layer(layer)
    assert(event_fired, "No layer addition event was issued")
    assert_equal(3, @map.layers.count)
    assert_equal("Another layer", @map.get_layer(-1).name)
    assert_equal(Map::DEFAULT_LAYER_COMPRESSION, @map.get_layer(-1).compression)
    assert_equal(Map::DEFAULT_LAYER_ENCODING, @map.get_layer(-1).encoding)
    assert_equal(layer, @map.get_layer(-1))

    event_fired = false
    layer = TiledTmx::TileLayer.new(@map, :name => "A layer with custom compression")
    layer.compression = "gzip"
    @map.add_layer(layer)
    assert(event_fired, "No layer addition event was issued")
    assert_equal("gzip", @map.get_layer(-1).compression)

    event_fired = false
    layer = TiledTmx::TileLayer.new(@map, :name => "A layer with custom encoding")
    layer.encoding = "csv"
    @map.add_layer(layer)
    assert(event_fired, "No layer addition event was issued")
    assert_equal("csv", @map.get_layer(-1).encoding)

    event_fired = false
    layer = TiledTmx::TileLayer.new(@map, :name => "A layer with custom compression and encoding")
    layer.compression = "gzip"
    layer.encoding = "csv"
    @map.add_layer(layer)
    assert(event_fired, "No layer addition event was issued")
    assert_equal("gzip", @map.get_layer(-1).compression)
    assert_equal("csv", @map.get_layer(-1).encoding)
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

  def test_width_and_height
    event_fired = false
    @map.observe(:size_changed) do |event, sender, info|
      event_fired = true
    end

    @map.width = 100
    assert event_fired, "No :size_changed event was fired"
    assert_equal(100, @map.width)

    event_fired = false
    @map.height = 123
    assert event_fired, "No :size_changed event was issued"
    assert_equal(123, @map.height)
  end

  def test_generic_objects
    @map.add_layer(:objectgroup, name: "Objects") # z = 1

    o = MapObject.new
    o.add_page do |page|
      assert_raises(ArgumentError) do
        page.trigger = :nonexistant
      end
    end

    o = MapObject.new
    o.add_page do |page|
      page.graphic = "foo"
      page.trigger = "activate"
      page.code = <<-CODE
        42
      CODE
    end
    o.add_page do |page|
      page.trigger = :immediate
    end

    assert_equal 2, o.pages.count
    assert_equal 0, o.pages.first.number
    assert_equal Pathname.new("foo"), o.pages.first.graphic
    assert_equal :activate, o.pages.first.trigger
    assert_equal 42, eval(o.pages.first.code)
    assert_equal :immediate, o.pages.last.trigger
    refute o.pages.last.graphic.exist?

    Dir.mktmpdir do |tmpdir|
      @map.add_object(1, o)
      path = @map.save(tmpdir)
      map = Map.load_xml(path)

      o2 = map.get_object(o.name)

      assert_equal 2, o2.pages.count
      assert_equal 0, o2.pages.first.number
      assert_equal Pathname.new("foo"), o2.pages.first.graphic
      assert_equal :activate, o2.pages.first.trigger
      assert_equal 42, eval(o2.pages.first.code)
      assert_equal :immediate, o2.pages.last.trigger
      refute o2.pages.last.graphic.exist?
    end
  end

  def test_templated_objects
    skip "Need to write a test for templated objects"
    #@map.add_layer(:objectgroup, name: "Objects") # z = 1
    #
    #t = Template.new "chest" do
    #  page do
    #    parameter :item
    #    parameter :count, :default => 1
    #
    #    code <<-CODE
    #      "%{item}" * %{count}
    #    CODE
    #  end
    #end
    #
    #o = MapObject.from_template(t)
    #o.modify_params([{:item => "banana", :count => 3}])
    #
    #t.result(o.params) do |page, result|
    #  assert_equal 0, page.number
    #  assert_equal "bananabananabanana", eval(result)
    #end
  end

end

#t = Template.new("chest")
#t.properties[:graphic] = "fdgd"
#t.parameters = {:item => {:type => :string}, :count => {:type => :number, :default => 1}}
#t.code = <<CODE
#%{count}.times do
#  $player.items << RPG::Item[%{item}]
#end
#CODE
