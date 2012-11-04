# -*- coding: utf-8 -*-
require_relative "helpers"

class ProjectTest < Test::Unit::TestCase
  include OpenRubyRMK
  include OpenRubyRMK::Backend
  include OpenRubyRMK::Backend::AdditionalAssertions

  def setup
    @tmpdir = Pathname.new(Dir.mktmpdir)
  end

  def teardown
    @tmpdir.rmtree if @tmpdir.directory? # Might be removed from a test
  end

  def test_paths
    pr = Project.new(@tmpdir)
    assert_equal(@tmpdir, pr.paths.root)
    assert_equal(@tmpdir + "bin" + "#{@tmpdir.basename}.rmk", pr.paths.rmk_file)
    assert_equal(@tmpdir + "data", pr.paths.data_dir)
    assert_equal(@tmpdir + "data" + "maps", pr.paths.maps_dir)
    assert_equal(@tmpdir + "data" + "maps" + "maps.xml", pr.paths.maps_file)
    assert_equal(@tmpdir + "data" + "graphics", pr.paths.graphics_dir)
    assert_equal(@tmpdir + "data" + "graphics" + "tilesets", pr.paths.tilesets_dir)
    assert_equal(@tmpdir + "data" + "scripts", pr.paths.scripts_dir)
  end

  def test_creation
    pr = Project.new(@tmpdir)
    assert_file(@tmpdir + "bin" + "#{@tmpdir.basename}.rmk")
    assert_dir(@tmpdir + "data")
    assert_dir(@tmpdir + "data" + "maps")
    assert_file(@tmpdir + "data" + "maps" + "maps.xml")
    assert_dir(@tmpdir + "data" + "graphics" + "tilesets")
    assert_dir(@tmpdir + "data" + "scripts")
    assert_equal(Backend.version, pr.config["open_ruby_rmk"]["version"])
    assert(pr.config["project"]["name"], "Project has no full name!")
    assert_equal("0.0.1", pr.config["project"]["version"])
  end

  def test_loading
    pr = Project.new(@tmpdir)
    pr.add_root_map(Map.new(2))
    pr.root_maps.last[:name] = "foo-map"
    pr.save

    pr = Project.load_dir(@tmpdir)
    assert_equal(@tmpdir, pr.paths.root)
    assert_equal(2, pr.root_maps.count)
    assert_equal("foo-map", pr.root_maps.last[:name])
  end

  def test_deletion
    pr = Project.new(@tmpdir)
    pr.delete!
    refute_exists(@tmpdir)
  end

  def test_saving
    pr = Project.new(@tmpdir)
    assert_file(@tmpdir + "data" + "maps" + "0001.tmx") # One map is in the skeleton by default
    assert_equal(1, Nokogiri::XML(File.read(@tmpdir + "data" + "maps" + "maps.xml")).root.xpath("map").count)
    pr.add_root_map(Map.new(2)) # Now add a new map
    pr.save
    assert_file(@tmpdir + "data" + "maps" + "0002.tmx")
    assert_equal(2, Nokogiri::XML(File.read(@tmpdir + "data" + "maps" + "maps.xml")).root.xpath("map").count)

    pr.add_root_map(Map.new(2)) # Duplicate ID!
    assert_raises(OpenRubyRMK::Backend::Errors::DuplicateMapID){pr.save}

    pr = Project.new(@tmpdir)
    pr.config["foo"] = "bar"
    pr.save
    assert_equal("bar", YAML.load_file(@tmpdir.join("bin", "#{@tmpdir.basename}.rmk"))["foo"])
  end

end
