# -*- coding: utf-8 -*-

# A project is the toplevel entity the OpenRubyRMK copes with.
# This is an observable object (by utilising Ruby’s Observable
# module) that emits events for certain action. To subscribe
# to this events, use something like the following:
#
#   project.observe(:root_map_added){|event, map| puts "Root map with ID #{map.id} added!"}
class OpenRubyRMK::Backend::Project
  include OpenRubyRMK::Backend::Invalidatable
  include OpenRubyRMK::Backend::Eventable

  #Struct encapsulating all the path information for a
  #single project.
  Paths = Struct.new(:root, :rmk_file, :data_dir, :resources_dir, :maps_dir, :maps_file, :graphics_dir, :tilesets_dir, :scripts_dir) do
    def initialize(root) # :nodoc:
      self.root          = Pathname.new(root).expand_path
      self.rmk_file      = self.root     + "bin" + "#{self.root.basename}.rmk"
      self.data_dir      = self.root     + "data"
      self.resources_dir = data_dir      + "resources"
      self.graphics_dir  = resources_dir + "graphics"
      self.maps_dir      = data_dir      + "maps"
      self.maps_file     = maps_dir      + "maps.xml"
      self.tilesets_dir  = graphics_dir  + "tilesets"
      self.scripts_dir   = data_dir      + "scripts"
    end
  end

  #The Paths struct belonging to this project.
  attr_reader :paths
  #This project’s main configuration, i.e. the parsed contents
  #of the +rmk+ file.
  attr_reader :config
  # The root maps of a project. Don’t append to this directly,
  # use #add_root_map.
  attr_reader :root_maps
  # All the graphics, music, etc. files available to a project.
  # An array of Resource objects.
  attr_reader :resources

  #Loads an OpenRubyRMK project from a project directory.
  #==Parameter
  #[path] The path to the project directory, i.e. the directory
  #       containing the bin/ subdirectory with the main RMK file.
  #==Raises
  #[NonexistantDirectory]
  #  +path+ doesn’t exist.
  #==Return value
  #An instance of this class representing the project.
  def self.load_dir(path)
    raise(OpenRubyRMK::Backend::Errors::NonexistantDirectory.new(path)) unless File.directory?(path)

    proj = allocate
    proj.instance_eval do
      @paths       = Paths.new(path)
      @config      = YAML.load_file(@paths.rmk_file.to_s).recursively_symbolize_keys
      @root_maps   = OpenRubyRMK::Backend::MapStorage.load_maps_tree(@paths.maps_dir, @paths.maps_file)

      reload_resources!
    end

    proj
  end

  #Creates a new project directory at the given path. This method
  #will copy the files from the skeleton archive (see Paths::SKELETON_FILE)
  #into that directory and then load the resulting project.
  #==Parameter
  #Path where to create a new project directory.
  #==Return value
  #A new instance of this class representing the created project.
  def initialize(path)
    @paths       = Paths.new(path)
    create_skeleton
    @config      = YAML.load_file(@paths.rmk_file.to_s).recursively_symbolize_keys
    @root_maps   = OpenRubyRMK::Backend::MapStorage.load_maps_tree(@paths.maps_dir, @paths.maps_file) # Skeleton may (and most likely does) contain maps

    reload_resources!
  end

  # Human-readable description.
  def inspect
    "#<#{self.class} #{@paths.root} \"#{@config[:name]}\">"
  end

  #Recursively deletes the project directory and invalidates this
  #object. Do not use it anymore after calling this.
  def delete!
    # 1. Remove the project directory
    @paths.root.rmtree

    # 2. Commit suicide
    invalidate!
  end

  # Adds a new root map to the project. All observers listening
  # to the :root_map_added event will be notified.
  def add_root_map(map)
    changed
    @root_maps << map
    notify_observers(:root_map_added, :map => map)
  end

  # Saves all the project’s pecularities out to disk.
  def save
    @paths.rmk_file.open("w"){|f| YAML.dump(@config.recursively_stringify_keys, f)}
    OpenRubyRMK::Backend::MapStorage.save_maps_tree(@paths.maps_dir, @paths.maps_file, *@root_maps)
  end

  # Recursively skims through the resources dir and
  # updates the list of resources. This is called automatically
  # when creating/loading a project, so you don’t have to call
  # it manually in these cases.
  def reload_resources!
    @resources = []

    @paths.resources_dir.find do |path|
      next if path.directory? or path.extname == ".yml" # Don’t load the info files as resources

      if path.basename.to_s == "DUMMY" # We’re using these in development as placeholders
        warn("Warning: Ignoring dummy resource: #{path}")
      else
        @resources << OpenRubyRMK::Backend::Resource.new(path)
      end
    end

    # This can’t be modified for safety reasons.
    @resources.freeze
  end

  private

  #Extracts the skeleton archive into the project directory
  #and renames the name_of_proj.rmk file to the project’s name.
  def create_skeleton
    FileUtils.cp_r "#{OpenRubyRMK::Backend::DATA_DIR}/skeleton/.", @paths.root
    File.rename(@paths.root.join("bin", "name_of_proj.rmk"), @paths.rmk_file)
  end

end
