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

  def generate_resource
    Dir.mkdir(@tmpdir + "stuff")
    File.open(@tmpdir + "stuff" + "myfile.txt", "w") do |f|
      f.puts("Awesome resource")
    end
    File.open(@tmpdir + "stuff" + "myfile.txt.yml", "w") do |f|
      hsh = {
        "year" => 2000,
        "license" => "CC-BY",
        "author" => "Nobody",
        "extra" => "Nix da!!"
      }
      YAML.dump(hsh, f)
    end

    @resource_path = @tmpdir + "stuff" + "myfile.txt"
  end

  def test_paths
    pr = Project.new(@tmpdir)
    assert_equal(@tmpdir, pr.paths.root)
    assert_equal(@tmpdir + "project.rmk", pr.paths.rmk_file)
    assert_equal(@tmpdir + "data", pr.paths.data_dir)
    assert_equal(@tmpdir + "data" + "maps", pr.paths.maps_dir)
    assert_equal(@tmpdir + "data" + "maps" + "maps.xml", pr.paths.maps_file)
    assert_equal(@tmpdir + "data" + "resources", pr.paths.resources_dir)
    assert_equal(@tmpdir + "data" + "resources" + "graphics", pr.paths.graphics_dir)
    assert_equal(@tmpdir + "data" + "resources" + "graphics" + "tilesets", pr.paths.tilesets_dir)
    assert_equal(@tmpdir + "data" + "scripts", pr.paths.scripts_dir)
  end

  def test_creation
    pr = Project.new(@tmpdir)
    assert_file(@tmpdir + "project.rmk")
    assert_dir(@tmpdir + "data")
    assert_dir(@tmpdir + "data" + "maps")
    assert_file(@tmpdir + "data" + "maps" + "maps.xml")
    assert_dir(@tmpdir + "data" + "resources" + "graphics" + "tilesets")
    assert_dir(@tmpdir + "data" + "scripts")
    assert_file(@tmpdir + "data" + "resources" + "graphics" + "misc" + "ruby.png")
    assert_dir(@tmpdir + "data" + "categories")
    assert_equal(Backend.version, pr.config[:open_ruby_rmk][:version])
    assert(pr.config[:project][:name], "Project has no full name!")
    assert_equal("0.0.1", pr.config[:project][:version])
  end

  def test_loading
    pr = Project.new(@tmpdir)
    pr.add_root_map(Map.new(2))
    pr.root_maps.last[:name] = "foo-map"
    pr.save

    pr = Project.load_project_file(@tmpdir + "project.rmk")
    assert_equal(@tmpdir, pr.paths.root)
    assert_equal(2, pr.root_maps.count)
    assert_equal("foo-map", pr.root_maps.last[:name])
  end

  def test_deletion
    pr = Project.new(@tmpdir)
    pr.delete!
    refute_exists(@tmpdir)
  end

  def test_map_saving
    pr = Project.new(@tmpdir)
    assert_file(@tmpdir + "data" + "maps" + "0001.tmx") # One map is in the skeleton by default
    assert_equal(1, Nokogiri::XML(File.read(@tmpdir + "data" + "maps" + "maps.xml")).root.xpath("map").count)
    pr.add_root_map(Map.new(2)) # Now add a new map
    pr.save
    assert_file(@tmpdir + "data" + "maps" + "0002.tmx")
    assert_equal(2, Nokogiri::XML(File.read(@tmpdir + "data" + "maps" + "maps.xml")).root.xpath("map").count)

    pr.add_root_map(Map.new(2)) # Duplicate ID!
    assert_raises(OpenRubyRMK::Backend::Errors::DuplicateMapID){pr.save}
  end

  def test_config_saving
    pr = Project.new(@tmpdir)
    pr.config["foo"] = "bar"
    pr.save
    assert_equal("bar", YAML.load_file(@tmpdir + "project.rmk")["foo"])
  end

  def test_category_saving_and_loading
    pr = Project.new(@tmpdir)
    pr.categories.clear # Delete predefined categories
    cat = Category.new("Items")
    cat.define_attribute :name, type: :string, description: "The name"
    pr.add_category(cat)
    pr.save

    assert_file @tmpdir + "data" + "categories" + "Items.xml"

    pr = Project.load_project_file(@tmpdir + "project.rmk")
    assert_equal 1, pr.categories.count
    assert_equal "Items", pr.categories.first.name
    assert_equal [:name], pr.categories.first.allowed_attribute_names
    assert_equal :string, pr.categories.first[:name].type
    assert_equal "The name", pr.categories.first[:name].description
  end

  def test_root_maps
    pr = Project.new(@tmpdir)
    assert_equal(1, pr.root_maps.count)

    m2 = Map.new(2)
    pr.add_root_map(m2)
    assert_equal(2, pr.root_maps.count)

    m3 = Map.new(3)
    pr.add_root_map(m3)
    assert_equal(3, pr.root_maps.count)

    pr.remove_root_map(m2)
    assert_equal(2, pr.root_maps.count)

    # Not a root map
    m4 = Map.new(4)
    m4.parent = m3
    assert_equal(2, pr.root_maps.count)
    pr.remove_root_map(m4)
    assert_equal(2, pr.root_maps.count) # Nothing done
  end

  def test_resources
    generate_resource

    pr = Project.new(@tmpdir + "myproject")
    pr.add_resource(@resource_path, "graphics/misc")
    assert_file(@tmpdir + "myproject" + "data" + "resources" + "graphics" + "misc" + @resource_path.basename)
    assert_file(@tmpdir + "myproject" + "data" + "resources" + "graphics" + "misc" + "#{@resource_path.basename}.yml")

    pr.remove_resource("graphics/misc/#{@resource_path.basename}")
    refute_exists(@tmpdir + "myproject" + "data" + "resources" + "graphics" + "misc" + @resource_path.basename)
    refute_exists(@tmpdir + "myproject" + "data" + "resources" + "graphics" + "misc" + "#{@resource_path.basename}.yml")
  end

  def test_categories
    pr = Project.new(@tmpdir + "myproject")
    pr.categories.clear # Remove predefined categories
    assert_empty pr.categories

    callback_fired = false
    pr.observe(:category_added){callback_fired = true}

    items = Category.new("Items")
    pr.add_category(items)
    assert callback_fired, "Didn't issue :category_added event!"
    assert_includes pr.categories, items

    items.define_attribute :name, type: :string, description: "The name"
    assert_includes pr.categories, items

    skills = Category.new("Skills")
    pr.add_category(skills)
    assert_includes pr.categories, skills
    assert_includes pr.categories, items
    assert_equal 2, pr.categories.count

    callback_fired = false
    pr.observe(:category_removed){callback_fired = true}

    pr.remove_category(skills)
    assert callback_fired, "Didn't issue the :category_removed event!"
    refute_includes pr.categories, skills
    assert_includes pr.categories, items
    assert_equal 1, pr.categories.count

    pr.remove_category("Items")
    refute_includes pr.categories, items
    assert_empty pr.categories
  end

end
