# -*- coding: utf-8 -*-
require_relative "helpers"

class ProjectTest < Test::Unit::TestCase
  include OpenRubyRMK
  include OpenRubyRMK::Backend

  def assert_dir(path, msg = nil)
    assert(File.directory?(path), msg || "Not a directory: #{path}")
  end

  def assert_file(path, msg = nil)
    assert(File.file?(path), msg || "Not a file: #{path}")
  end

  def refute_exists(path, msg = nil)
    assert(!File.exists?(path), msg || "File exists: #{path}")
  end

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
    assert_equal(Backend::VERSION, pr.config["open_ruby_rmk"]["version"])
    assert(pr.config["project"]["name"], "Project has no full name!")
    assert_equal("0.0.1", pr.config["project"]["version"])
  end

  def test_loading
    pr = Project.new(@tmpdir)
    pr.root_maps << Map.new(1)
    pr.root_maps.last[:name] = "foo-map"
    pr.save

    pr = Project.load_dir(@tmpdir)
    assert_equal(@tmpdir, pr.paths.root)
    assert_equal(1, pr.root_maps.count)
    assert_equal("foo-map", pr.root_maps.first[:name])
  end

  def test_deletion
    pr = Project.new(@tmpdir)
    pr.delete!
    refute_exists(@tmpdir)
  end

  def test_saving
    pr = Project.new(@tmpdir)
    assert_equal(0, Nokogiri::XML(File.read(@tmpdir + "data" + "maps" + "maps.xml")).root.xpath("map").count)
    pr.root_maps << Map.new(1)
    pr.save
    assert_file(@tmpdir + "data" + "maps" + "0001.tmx")
    assert_equal(1, Nokogiri::XML(File.read(@tmpdir + "data" + "maps" + "maps.xml")).root.xpath("map").count)
  end

end
