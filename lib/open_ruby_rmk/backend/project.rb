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

  # Struct encapsulating all the path information for a
  # single project.
  Paths = Struct.new(:root, :rmk_file, :data_dir, :resources_dir, :maps_dir, :maps_file, :graphics_dir, :tilesets_dir, :scripts_dir, :bin_dir, :start_file, :categories_dir, :templates_dir) do
    def initialize(root) # :nodoc:
      self.root          = Pathname.new(root).expand_path
      self.rmk_file      = self.root     + "project.rmk"
      self.data_dir      = self.root     + "data"
      self.resources_dir = data_dir      + "resources"
      self.graphics_dir  = resources_dir + "graphics"
      self.maps_dir      = data_dir      + "maps"
      self.maps_file     = maps_dir      + "maps.xml"
      self.tilesets_dir  = graphics_dir  + "tilesets"
      self.scripts_dir   = data_dir      + "scripts"
      self.bin_dir       = self.root     + "bin"
      self.start_file    = bin_dir       + "start.rb"
      self.categories_dir = data_dir     + "categories"
      self.templates_dir = data_dir      + "templates"
    end
  end

  # The Paths struct belonging to this project.
  attr_reader :paths
  # This project’s main configuration, i.e. the parsed contents
  # of the +rmk+ file.
  attr_reader :config
  # The root maps of a project. Don’t work on this directly,
  # use #add_root_map and #remove_root_map.
  attr_reader :root_maps
  # The categories of a project. Don’t work on this directly,
  # use #add_category and #remove_category.
  attr_reader :categories
  # The event templates of a project. Don’t work on this directly,
  # use #add_template and #remove_template.
  attr_reader :templates

  # Loads an OpenRubyRMK project from a project file and it’s
  # associated directory.
  # ==Parameter
  # [path] The path to the project file, i.e. the file
  #        ending in .rmk.
  # ==Raises
  # [NonexistantFile]
  #   +path+ doesn’t exist.
  # [InvalidPath]
  #   The directory structure below +path+ is damaged somehow,
  #   some file or directory isn’t where it was expected to be.
  # ==Return value
  # An instance of this class representing the project.
  def self.load_project_file(path)
    raise(OpenRubyRMK::Backend::Errors::NonexistantFile.new(path)) unless File.file?(path)

    proj = allocate
    proj.instance_eval do
      @paths       = Paths.new(File.dirname(path))
      @config      = YAML.load_file(@paths.rmk_file.to_s).recursively_symbolize_keys
      @root_maps   = OpenRubyRMK::Backend::MapStorage.load_maps_tree(@paths.maps_dir, @paths.maps_file)
      @categories  = @paths.categories_dir.children.map{|path| OpenRubyRMK::Backend::Category.from_file(path) if path.file?}
      @templates   = @paths.templates_dir.children.map{|path| OpenRubyRMK::Backend::Template.from_file(path) if path.file?}
    end

    proj
  rescue Errno::ENOENT, Errno::EISDIR, Errno::ENOTDIR => e
    # Extract the path from the exception and transform it into a
    # proper error.
    path = e.message.split("-").drop(1).join.strip
    raise(OpenRubyRMK::Backend::Errors::InvalidPath.new(path))
  end

  # Creates a new project directory at the given path. This method
  # will copy the files from the skeleton archive (see Paths::SKELETON_FILE)
  # into that directory and then load the resulting project.
  # ==Parameter
  # Path where to create a new project directory. Note this is *not*
  # the full path to the RMK file (which will then in turn be created),
  # but to the toplevel project directory.
  # ==Return value
  # A new instance of this class representing the created project.
  def initialize(path)
    @paths       = Paths.new(path)
    create_skeleton
    @config      = YAML.load_file(@paths.rmk_file.to_s).recursively_symbolize_keys
    @root_maps   = OpenRubyRMK::Backend::MapStorage.load_maps_tree(@paths.maps_dir, @paths.maps_file) # Skeleton may (and most likely does) contain maps
    @categories  = @paths.categories_dir.children.map{|path| OpenRubyRMK::Backend::Category.from_file(path) if path.file?}
    @templates   = @paths.templates_dir.children.map{|path| OpenRubyRMK::Backend::Template.from_file(path) if path.file?}
  end

  # Human-readable description.
  def inspect
    "#<#{self.class} #{@paths.root} \"#{full_name}\">"
  end

  # Short name of the project, i.e. the name of the project
  # root directory.
  def short_name
    @paths.root.basename.to_s
  end

  # Full name of the project, i.e. the string configured in
  # the project’s configuration file.
  def full_name
    @config[:project][:name]
  end

  #Recursively deletes the project directory and invalidates this
  #object. Do not use it anymore after calling this.
  def delete!
    # 1. Remove the project directory
    @paths.root.rmtree

    # 2. Commit suicide
    invalidate!
  end

  # Adds a new root map to the project.
  # == Events
  # [root_map_added]
  #   Always issued when this method is called. The :map
  #   parameter will receive the added Map instance.
  def add_root_map(map)
    changed
    @root_maps << map
    notify_observers(:root_map_added, :map => map)
  end

  # Removes a root map from the project. Does nothing
  # if the +map+ isn’t a root map of this project.
  # == Parameters
  # [map]
  #   The Map instance to delete from the list of root
  #   maps.
  # == Events
  # [root_map_removed]
  #   Always issued when this method is called. The
  #   :map parameter will receive the removed Map
  #   instance.
  # == Remarks
  # This method doesn *not* delete the map from the filesystem
  # immediately, this will be done when calling Project#save.
  def remove_root_map(map)
    return unless @root_maps.include?(map)

    changed
    @root_maps.delete(map)
    notify_observers(:root_map_removed, :map => map)
  end

  # Adds the a Template instance to the list of templates for this
  # project.
  # == Parameter
  # [template]
  #   The Template to add to the project.
  # == Events
  # [template_added]
  #   Only issued if +template+ is really added to the project.
  #   The callback receives +template+ as :template.
  # == Remarks
  # If +template+ is already part of the project, does nothing.
  def add_template(template)
    return if @templates.include?(template)

    changed
    @templates << template
    notify_observers(:template_added, :template => template)
  end

  # Removes a Template from the project.
  # == Parameter
  # [cat]
  #   The Template instance to remove. May also be a string,
  #   in which case the first template with this string as
  #   its +name+ is removed.
  # == Events
  # [template_removed]
  #   Only issued if a template was really removed from the
  #   project. The callback receives the removed Template
  #   instance as :template.
  # == Remarks
  # If +template+ is not part of the project or a template with this
  # name can’t be found, nothing happens.
  def remove_template(template)
    template = @templates.find{|t| t.name == template} unless template.kind_of?(OpenRubyRMK::Backend::Template)
    return unless @templates.include?(template)

    changed
    @templates.delete(template)
    notify_observers(:template_removed, :template => template)
  end

  # Adds the a Category instance to the list of categories for this
  # project.
  # == Parameter
  # [cat]
  #   The Category to add to the project.
  # == Events
  # [category_added]
  #   Only issued if +cat+ is really added to the project.
  #   The callback receives +cat+ as :category.
  # == Remarks
  # If +cat+ is already part of the project, does nothing.
  def add_category(cat)
    return if @categories.include?(cat)

    changed
    @categories << cat
    notify_observers(:category_added, :category => cat)
  end

  # Removes a Category from the project.
  # == Parameter
  # [cat]
  #   The Category instance to remove. May also be a string,
  #   in which case the first category with this string as
  #   its +name+ is removed.
  # == Events
  # [category_removed]
  #   Only issued if a category was really removed from the
  #   project. The callback receives the removed Category
  #   instance as :category.
  # == Remarks
  # If +cat+ is not part of the project or a category with this
  # name can’t be found, nothing happens.
  def remove_category(cat)
    cat = @categories.find{|c| c.name == cat} unless cat.kind_of?(OpenRubyRMK::Backend::Category)
    return unless @categories.include?(cat)

    changed
    @categories.delete(cat)
    notify_observers(:category_removed, :category => cat)
  end

  # Saves all the project’s pecularities out to disk.
  def save
    # The project settings
    @paths.rmk_file.open("w"){|f| YAML.dump(@config.recursively_stringify_keys, f)}

    # The categories (clearing the directory to ensure deleted
    # categories really get removed)
    @paths.categories_dir.each_child{|path| path.delete if path.file?}
    @categories.each{|cat| cat.save(@paths.categories_dir)}

    # The templates (again, clearing the directory to ensure
    # removed templates really get deleted)
    @paths.templates_dir.each_child{|path| path.delete if path.file?}
    @templates.each{|template| template.save(@paths.templates_dir)}

    # The maps (clearing the directory to ensure deleted
    # maps really get removed)
    OpenRubyRMK::Backend::MapStorage.save_maps_tree(@paths.maps_dir, @paths.maps_file, *@root_maps)
  end

  # Packages everything up into a distributable package.
  # Depending on the platform, this may be a tarball, an
  # OCRA executable, or something entirely different.
  def package(path, platform)
    path = Pathname.new(path).expand_path
    raise(NotImplementedError, "Packaging is not yet implemented!")
  end

  # Adds a resource to the project.
  # == Parameters
  # [path]
  #   A (preferably absolute) path to the file you want to
  #   add to the project. The resource information file will
  #   be determined by appending ".yml" to this.
  # [target_dir]
  #   Where you want to copy the resource exactly. This is a
  #   path relative to the <b>resources/</b> directory of
  #   the project (intermediate nonexisting directory will
  #   not be created).
  # == Raises
  # Everything that Backend::Resource::new raises.
  # == Events
  # [resource_added]
  #   Emitted always when this method is called. The callback
  #   gets the :resource as a Backend::Resource instance passed.
  # == Return value
  # An instance of Backend::Resource describing the newly
  # added resource.
  # == Remarks
  # The resource is added immediately, you don’t have to call
  # #save to get it into the project directory tree.
  def add_resource(path, target_dir)
    res = OpenRubyRMK::Backend::Resource.new(path)
    changed
    FileUtils.cp(res.path, @paths.resources_dir + target_dir)
    FileUtils.cp(res.info_file, @paths.resources_dir + target_dir)
    notify_observers(:resource_added, :resource => res)
    res
  end

  # *Permanently*, *irrevocabily*, and *immediately* deletes a
  # resource from the project. The corresponding resource
  # information file is also deleted.
  # == Parameter
  # [path]
  #   The path to the resource to delete, relative to the
  #   project <b>resources/</b> directory. The resource information
  #   file’s path will be determined by simply appending ".yml"
  #   to this.
  # == Events
  # [resource_deleted]
  #   Emmitted always when this method is called; the callback
  #   gets passed the deleted :resource as a Backend::Resource
  #   instance (but note Resource#valid? will return +false+ as
  #   the resource doesn’t exist on disk anymore).
  # == Return value
  # A Backend::Resource object describing the deleted resource.
  # Again, Resource#valid? will return +false+ for that resource
  # for the above reasons.
  def remove_resource(path)
    res = OpenRubyRMK::Backend::Resource.new(@paths.resources_dir + path)
    changed
    File.delete(res.path)
    File.delete(res.info_file)
    notify_observers(:resource_deleted, :resource => res) # res.valid? will return false
    res
  end

  private

  #Extracts the skeleton archive into the project directory
  #and renames the name_of_proj.rmk file to the project’s name.
  def create_skeleton
    FileUtils.cp_r "#{OpenRubyRMK::Backend::DATA_DIR}/skeleton/.", @paths.root # Note trailing . for copying directory contents
  end

end
