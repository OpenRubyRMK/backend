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
#
# == Map tree fun
# The map tree is exactly that: A tree of maps. Each map knows
# about its immediate parent as well as its immediate children.
# This has the nice effect that to associate a Project with all
# the maps, you just have to know about the little list of root
# maps that don’t have a parent themselves (and for which #root?
# returns true). However, you aren’t limited to inspecting the
# tree. You can do all those evil kinds of things with it that
# are possible with a tree, i.e. you can remove entire subtrees,
# add those or just remount them elsewhere in the tree (but note
# it is not possible to mount the same subtree in different
# places in the map tree--that would be insidious). To reflect
# what these operations do, you should make use of the #mount
# and #unmount methods, which mount a subtree onto another
# tree at the specified point or remove it from there,
# respectively. You could also use the #parent= method, but
# #mount and #unmount is usually more clear as it resembles
# the terminology generally known from Linux file system
# operations (the +mount+ and +umount+ commands).
#
# == Objects on the map
# Objects on the map are represented the default way ruby-tmx
# does, i.e. by means of a TiledTmx::ObjectGroup layer that
# contains any number of TiledTmx::Object instances. However,
# to ease object editing for the user, we set up some conventions
# on these quite liberate objects:
#
# 1. The +name+ attribute is set to a map-unique ID that allows
#    to directly retrieve the object from the map (via #get_object).
# 2. The +_name+ *property* (see TiledTmx::PropertySet) can
#    be set to any name that is human-readable. #get_objects will
#    return all objects on this map that have that name. By default,
#    the +_name+ is generated from the ID.
#
# To easily obey these conventions, there’s the MapObject class,
# which only is a shallow wrapper around TiledTmx::Object; everything
# it can do could also be done directly with TiledTmx::Object instances,
# but it ensures you don’t make mistakes regarding the above conventions.
# Use #add_object to add these objects to the map, and #get_object /
# #get_objects to retrieve them directly retrieve them as MapObject
# instances.
class OpenRubyRMK::Backend::Map < TiledTmx::Map
  include OpenRubyRMK::Backend::Eventable

  # Number of tile columns to use for new maps.
  DEFAULT_MAP_WIDTH = 20
  # Number of tile rows to use for new maps.
  DEFAULT_MAP_HEIGHT = 15
  # Number of pixels to use for the edges of a tile.
  DEFAULT_TILE_EDGE = 32
  # The compression to instruct ruby-tmx to use for layer tiles.
  DEFAULT_LAYER_COMPRESSION = "zlib"
  # The encoding used for the compressed layer tiles, for ruby-tmx.
  DEFAULT_LAYER_ENCODING    = "base64"

  # The ID of the map. Unique within a project.
  attr_reader :id

  # An (unsorted) array of child maps of this map.
  attr_reader :children

  # The parent map or +nil+ if this is a root map.
  attr_reader :parent

  # Returns the filename a map with ID +id+ is expected
  # to reside in.
  def self.format_filename(id)
    sprintf("%04d.tmx", id)
  end

  def self.load_xml(path)
    # Initialize the tmx part of the object (see also the explanation
    # in #initialize further below).
    map = super

    # Now initialize the rest of the object.
    map.instance_eval do
      @id              = File.basename(path).to_s.to_i # Pathname<0001.map> -> "0001.map" -> 1
      @children        = []
      @parent          = nil
      @object_id_mutex = Mutex.new

      # Find the highest object ID on the entire map and
      # set it as the start for the object ID generator to
      # further ensure unique object IDs.
      @last_object_id = layers.reduce(0) do |memo, layer|
        next memo unless layer.kind_of?(TiledTmx::ObjectGroup)

        obj = layer.objects.max_by{|obj| obj.name.to_i}
        obj.name.to_i < memo ? memo : obj.name.to_i
      end
    end

    map
  end

  # Load a map from a given path. Note that the loaded map
  # will always be a root map, because a map file doesn’t
  # contain any hierarchy information; use the MapStorage
  # module to load an entire map tree. MapStorage uses
  # this method internally, so calling from_file directly
  # is not recommended.
  def self.from_file(path)
    load_xml(path)
  end

  # call-seq:
  #   new(id) → a_map
  #
  # Create a new map.
  # [id]
  #   The ID to assign to this map. If set to anything
  #   else than an integer, this method directly delegates
  #   to TiledTmx::Map.new without doing anything else (do
  #   not make use of that possibility, it’s a compatibility hack).
  # == Remarks
  # The map is created with the default map size
  # (see DEFAULT_MAP_WIDTH and DEFAULT_MAP_HEIGHT)
  # and one empty tile layer.
  def initialize(arg)
    # This is a bit nasty. ruby-tmx calls ::new from the
    # TiledTmx::Map::load_xml, with a hash as the only argument (also
    # using Ruby’s syntactic sugar for hash arguments). This makes it
    # impossible for us to change the method signature for
    # #initialize, hence the evil #kind_of? check below. This however
    # leaves us with an incomplete object (only the tmx part being
    # initialized), because we immediately +return+ as seen below (to
    # not get in the way of ruby-tmx’ initialisation process). To
    # ensure proper working, we therefore also overwrite the
    # ::load_xml method to initialize the rest of the object
    # correctly.

    if arg.kind_of?(Integer)
      super()
    else
      return super(arg)
    end

    @id       = Integer(arg)
    @children = []
    @parent   = nil
    @last_object_id = 0
    @object_id_mutex = Mutex.new

    # Set some default map values
    self.width       = DEFAULT_MAP_WIDTH
    self.height      = DEFAULT_MAP_HEIGHT
    self.orientation = :orthogonal
    self.tilewidth   = DEFAULT_TILE_EDGE
    self.tileheight  = DEFAULT_TILE_EDGE

    layer             = add_layer(:tile, :name => "Ground")
    layer.compression = DEFAULT_LAYER_COMPRESSION
    layer.encoding    = DEFAULT_LAYER_ENCODING

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
    properties[name.to_s]
  end

  # Set an extra property on the map.
  # == Parameters
  # [name]
  #   The name of the property to set. Autoconverted
  #   to a string.
  # [value]
  #   The value of the property. Autoconverted to
  #   a string.
  # == Events
  # [property_changed]
  #   Issued always when this method is called. The callback
  #   info hash gets :property and :new_value keys passed, representing
  #   the changed property (both are strings).
  def []=(name, value)
    changed
    properties[name.to_s] = value.to_s
    notify_observers(:property_changed, :property => name.to_s, :new_value => value.to_s)
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
  # the new relationship to the new parent. To improve
  # readability, you usually want to call #mount and
  # #unmount instead.
  # == Events
  # [parent_changed]
  #   Always emitted when this method is called. The info
  #   hash has a key :new_parent that contains the new
  #   parent map as a Backend::Map instance (or +nil+ if
  #   the map was made a root map).
  # [child_removed]
  #   Emitted on the old parent map object if this map had
  #   a parent previously. Passes +self+ as :old_child.
  # [child_added]
  #   Emitted on the new parent +map+ object passed to this
  #   method unless it’s +nil+. Passes +self+ as :new_child.
  # == Remarks
  # This is a quite expensive operation that causes many
  # callbacks to be run which in turn may also do heavy
  # work.
  def parent=(map)
    changed

    # Unless we’re a root map, delete us from the
    # old parent.
    if @parent
      @parent.changed
      @parent.children.delete(self)
      @parent.notify_observers(:child_removed, :old_child => self)
    end

    # Unless we’re made a root map now, add us to the
    # new parent.
    if map
      map.changed
      map.children << self
      map.notify_observers(:child_added, :new_child => map)
    end

    # Update our side of the relationship.
    @parent = map

    # Notify subscribers
    notify_observers(:parent_changed, :new_parent => map)
  end

  # Convenience method for calling:
  #   map.parent = nil
  # Improves readability by expressing "unmount this map
  # from the map tree".
  def unmount
    self.parent = nil
  end
  alias umount unmount # You’re a freak. You really don’t want to tell me umount is better than unmount, do you?

  # Convenience method for calling:
  #   map.parent = parent_map
  # Improves readability by expressing "mount this map
  # into the map tree at this specific point".
  def mount(parent_map)
    self.parent = parent_map
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

  # Adds a tileset to this map.
  # == Parameters
  # [tileset]
  #   A TiledTmx::Tileset instance to add to the
  #   underlying TiledTmx::Map instance.
  # [gid (nil)]
  #   The GID (global tile ID) for the tileset
  #   in this map. If +nil+, it will be automatically
  #   set to the first free GID. Be careful when
  #   setting this manually, you may screw up an
  #   entire map by shifting GIDs from a tileset
  #   over to another one with this.
  # == Event
  # [tileset_added]
  #   Always emitted when calling this method. The
  #   callback receives a :tileset parameter with
  #   the given +tileset+ object, and a :gid parameter
  #   with the GID used for this tileset on this map.
  def add_tileset(tileset, gid = nil)
    changed

    if gid
      super(tileset, gid)
    else
      gid = next_first_gid # FIXME: TiledTmx::Map#add_tileset should return the GID in a future version of ruby-tmx when using an optional parameter
      super(tileset, gid)
    end

    notify_observers :tileset_added, :gid => gid, :tileset => tileset
  end

  # Adds a layer to this map. The layer is placed on top of all
  # other layers.
  # == Parameters
  # [*args]
  #   Passed through to TiledTmx::Map#add_layer.
  #   Usually either a TiledTmx::Layer subclass instance or
  #   parameters to create one, like this:
  #     map.add_layer(:tile, :name => "Ground)
  # == Events
  # [layer_added]
  #   Always emitted when this method is called. The callback
  #   receives a :layer argument with a TiledTmx::Layer subclass
  #   instance as an attribute.
  def add_layer(*args)
    changed

    layer = super # ruby-tmx adds the layer on the top

    if layer.kind_of?(TiledTmx::TileLayer)
      layer.compression ||= DEFAULT_LAYER_COMPRESSION
      layer.encoding    ||= DEFAULT_LAYER_ENCODING
    end

    notify_observers :layer_added, :layer => layer
    layer
  end

  # Set the map’s width in tiles.
  # == Parameter
  # [num]
  #   The new number of columns.
  # == Events
  # [size_changed]
  #   Always emitted when calling this method. The callback
  #   receives a :size parameter width an array containing
  #   the new [width, height].
  def width=(num)
    changed
    super
    notify_observers :size_changed, :size => [width, height]
  end

  # Set the map’s height in tiles.
  # == Parameter
  # [num]
  #   The new number of rows.
  # == Events
  # [size_changed]
  #   Always emitted when calling this method. The callback
  #   receives a :size parameter width an array containing
  #   the new [width, height].
  def height=(num)
    changed
    super
    notify_observers :size_changed, :size => [width, height]
  end

  # Add a TMX ObjectGroup object to the map. This method adds the
  # required unique ID to the +object+, and generates a default
  # +_name+ property from that ID. If you set the +name+
  # attribute on the object, no ID will be generated; if you
  # set the +_name+ property, no name will be generated.
  # == Parameters
  # [layer_num]
  #   The Z index of the layer to add the object to.
  # [object]
  #   The MapObject to add to the layer.
  # == Raises
  # [ArgumentError]
  #   If the given layer number does not correspond to an ObjectGroup.
  # == Events
  # [object_added]
  #   Always emmitted when calling this method. The callback receives
  #   a :layer and an :object parameter representing the respective things.
  def add_object(layer_num, object)
    layer = get_layer(layer_num)
    raise(ArgumentError, "Layer ##{layer_num} is not an ObjectGroup (got #{layer.class})") unless layer.kind_of?(TiledTmx::ObjectGroup)

    changed
    object.name ||= generate_object_id.to_s
    object.properties["_name"] ||= sprintf("Event-#{OpenRubyRMK::Backend::MapObject.format_object_id(object.name)}")

    if object.kind_of?(OpenRubyRMK::Backend::MapObject)
      layer.objects << object.tmx_object
    else
      layer.objects << object
    end

    notify_observers :event_added, :layer => layer, :object => object
  end

  # Request the object with the given +id+.
  # == Parameters
  # [id]
  #   The map-unique ID of the object you want to retrieve.
  # == Return value
  # A TiledTmx::Object instance, if the ID is found, +nil+
  # otherwise.
  def get_object(id)
    idstr = id.to_s # The object name is always a string

    each_layer(TiledTmx::ObjectGroup) do |layer|
      layer.objects.each do |object|
        return OpenRubyRMK::Backend::MapObject.from_tmx_object(object) if object.name == idstr
      end
    end

    nil
  end

  # Request all objects that have been assigned the given +_name+
  # property.
  # == Parameters
  # [_name]
  #   The value of the +_name+ *property* (see TiledTmx::PropertySet)
  #   you’re looking for.
  # == Return value
  # An array of all objects matching the given +_name+. If none
  # matches, the array is empty.
  def get_objects(_name)
    result = []

    each_layer(TiledTmx::ObjectGroup) do |layer|
      layer.objects.each do |object|
        result << OpenRubyRMK::Backend::MapObject.from_tmx_object(object) if object.properties["_name"] == _name
      end
    end

    result
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
  #
  # Returns the path to the written file as a string.
  def save(maps_dir)
    target = File.join(maps_dir, self.class.format_filename(@id))
    File.open(target, "w"){|f| f.write(to_xml(target))}
    target
  end

  private

  # Generate a new and unique (as per this map) ID. Used
  # by MapEvent#initialize.
  def generate_object_id
    @object_id_mutex.synchronize do
      @last_object_id += 1
    end
  end

end
