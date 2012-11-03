# -*- coding: utf-8 -*-

# A map is the conglomerate of objects you interact most
# with when playing a game. It has a unique ID that is used
# to identify the map, and which is also used to name the
# file a map resides in.
#
# Maps are organised in a hierarchical mannor where each
# map can have any number of child maps. Those maps that
# do not have a parent map themselves, are called <i>root
# maps</i>. This list of root maps is normally attached to
# a project, so that it can access all available maps through
# the map tree.
#
# The map tree is stored inside a separate file called
# the map tree or map hierarchy file, usually the
# <tt>maps.xml</tt> file in the same directory in which
# the maps reside. This means that loading a map directly
# from a file without considering the hierarchy file will
# give you a root map regardless of how it was saved
# exactly. The storage and loading of the whole map hierarchy
# (i.e. the maps plus the hierarchy information) is handled
# by a separate worker module, MapStorage.
class OpenRubyRMK::Backend::Map

  # The ID of the map. Unique within a project.
  attr_reader :id

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
      @children  = []
      @parent    = nil
      @tmx_map   = TiledTmx::Map.load_xml(path)
    end

    map
  end

  # Create a new map.
  # == Parameters
  # [id] The ID to assign to this map.
  def initialize(id)
    @id       = Integer(id)
    @tmx_map  = TiledTmx::Map.new
    @children = []
    @parent   = nil

    # Set a default map name (this is not required, but improves
    # clarity).
    self[:name] = "Map_#@id"
  end

  # Read extra properties from the map, e.g.
  # the map’s <tt>:name</tt>.
  # == Parameters
  # [name] The name of the property to read. Autoconverted
  #        to a string.
  # == Return value
  # The property’s value; note this always is a string,
  # because XML doesn’t know about other data types.
  def [](name)
    @tmx_map.properties[name.to_s]
  end

  # Set an extra property on the map.
  # == Parameters
  # [name]
  #   The name of the property to set. Autoconverted
  #   to a string.
  # [value]
  #   The value of the property. Autoconverted to
  #   a string.
  def []=(name, value)
    @tmx_map.properties[name.to_s] = value.to_s
  end

  # Human-readable description.
  def inspect
    "#<#{self.class} '#{self[:name]}' (ID: #@id)>"
  end

  # Two maps are considered equal if they have the
  # same ID.
  def ==(other)
    return nil unless other.kind_of?(self.class)
    @id == other.id
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

  # Deletes this map (and all child maps!) from the map
  # tree.
  # Don’t use the object after this anymore; if it was
  # a root map, be sure to delete it from your project’s
  # list of root maps.
  #
  # Usually you want to call #delete! in order to also
  # erase the map file from the hard disk.
  def delete
    self.parent = nil
    @children.each{|map| map.delete}
  end

  # Calls #delete, then deletes the map file from the
  # directory you pass.
  # Don’t use the object after this anymore; if it was
  # a root map, be sure to delete it from your project’s
  # list of root maps.
  def delete!(maps_dir)
    delete
    target = File.join(maps_dir, self.class.format_filename(@id))
    File.delete(target)
  end

  # Checks whether this is a root map and if so,
  # returns true, otherwise false. A root map is
  # a map without a parent map.
  def root?
    @parent.nil?
  end

  #Checks whether any of this map’s children is
  #the given map. This is not done recursively,
  #see #ancestor? for this.
  #==Parameter
  #[map] Either an ID or an instance of this class to check for.
  #==Return value
  #A truth value.
  def has_child?(map)
    id = map.kind_of?(self.class) ? map.id : map
    @children.find{|map| map.id == id}
  end

  #Checks whether a map is somewhere an ancestor of
  #another, i.e. any of its children’s children etc.
  #contains the given map.
  #==Parameter
  #[map] Either an ID or an instance of this class to check for.
  #==Return value
  #Either +true+ or +false+.
  def ancestor?(map)
    id = map.kind_of?(self.class) ? map.id : map

    traverse do |child|
      return true if child.id == id
    end

    false
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
