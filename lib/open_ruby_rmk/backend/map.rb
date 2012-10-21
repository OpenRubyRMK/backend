# -*- coding: utf-8 -*-
class OpenRubyRMK::Backend::Map

  # The ID of the map. Unique within a project.
  attr_reader :id

  # The name of the map. Not necessarily unique.
  attr_reader :name

  # An (unsorted) array of child maps of this map.
  attr_reader :children

  # The parent map or +nil+ if this is a root map.
  attr_reader :parent

  # The underlying TiledTmx::Map object.
  attr_reader :tiled_map

  # Returns the filename a map with ID +id+ is expected
  # to reside in.
  def self.format_filename(id)
    sprintf("%04d.tmx", id)
  end

  # Load a map from a given path. Note that the loaded map
  # will always be a root map, because a map file doesn’t
  # contain any hierarchy information; use the MapStorage
  # module to load an entire map tree. MapStorage uses
  # this method internally, so calling from_file directly
  # is not recommended.
  def self.from_file(path)
    map = allocate
    map.instance_eval do
      @id        = File.basename(path).to_s.to_i # Pathname<0001.map> -> "0001.map" -> 1
      @name      = "<PLEASE IMPLEMENT LOADING THIS>" # TODO
      @children  = []
      @parent    = nil
      @tiled_map = TiledTmx::load_xml(File.read(path))
    end

    map
  end

  # Create a new map.
  # == Parameters
  # [id] The ID to assign to this map.
  # [name] The name of the map; generated from the ID
  #        if not given.
  def initialize(id, name = nil)
    @id       = Integer(id)
    @name     = name || "Map_#@id"
    @children = []
    @parent   = nil
    @tmx_map  = TiledTmx::Map.new
  end

  # Correctly dissolves the relationship between this
  # map and its old parent (if any), then establishes
  # the new relationship to the new parent.
  def parent=(map)
    # Unless we’re a root map, delete us from the
    # old parent.
    @parent.children.delete(self) if @parent

    # Unless we’re made a root map now, add us to the
    # new parent.
    map.children << self if map

    # Update our side of the relationship.
    @parent = map
  end

  # Checks whether this is a root map and if so,
  # returns true, otherwise false. A root map is
  # a map without a parent map.
  def root?
    @parent.nil?
  end

  #call-seq:
  #  traverse(include_self = false){|map| ...}
  #
  #Recursively iterates over this (optionally) and all child
  #maps.
  #==Parameters
  #[include_self] (false) If this is true, the block will be called
  #               once for +self+ before starting with the children.
  #[map]          (*Block*) The currently iterated child map, or,
  #               depending on the value of +include_self+, +self+.
  def traverse(include_self = false, &block)
    return enum_for __method__ unless block

    block.call(self) if include_self

    @children.each do |child|
      block.call(child)
      child.traverse(&block)
    end
  end

  # Saves this map into a properly named file inside +maps_dir+.
  # You shouldn’t use this method directly, because you’d lose
  # the map’s hierarchy information this way (this isn’t stored
  # inside a map file). Use the MapStorage module to save both
  # the map and the hierarchy information (MapStorage internally
  # calls this method if you worried about that).
  def save(maps_dir)
    target = File.join(maps_dir, self.class.format_filename(@id))
    File.open(target, "w"){|f| f.write(@tmx_map.to_xml)}
  end

end
