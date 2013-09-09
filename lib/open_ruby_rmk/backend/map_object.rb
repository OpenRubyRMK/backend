# -*- coding: utf-8 -*-

# By-reference wrapper class for TiledTmx::Object with an interface
# better suited for our purposes. All information you set on objects
# of this class is actually stored inside the underlying TiledTmx::Object
# instance, and you can mostly use these objects just like those except
# for the additional methods defined in this class.
#
# Besides creating MapObjects with ::new, you can make use of a template
# to easily create common objects without having to define them anew
# over and over again. For more information on writing templates,
# see OpenRubyRMK::Backend::Template. To use such a template, don’t
# call ::new, but rather ::from_template; also note that most of the
# methods working for "generic" map objects, i.e. those not created
# by means of templates, won’t work with the "non-generic" map objects
# returned by ::from_template. For instance, it is not possible to
# add or remove pages to/from a templated object, and the #pages
# method shows a different behaviour for templated objects. Instead,
# you can use the #modify_params method to change the settings used
# to evaluate the template in the game engine later on. As for anything
# else, you have to modify the Template instance itself.
#
# As said, MapObject is just a shallow wrapper around TiledTmx::Map.
# All relevant methods delegate to the wrapped instance of that class,
# except they intercept when not applicable to either generic or
# templated objects. Methods like #id provide a shortcut interface
# to querying the TMX +properties+ yourself and all modification
# methods will propely propage to the underlying TMX object.
#
# Use ::from_tmx_object in order to derive a MapObject from
# an existing TiledTmx::Object; it will automatically be
# detected whether it’s a generic or templated object.
#
# For more information, read the class docs of the Map class.
class OpenRubyRMK::Backend::MapObject

  # If a TMX object has this +type+, it is considered
  # to be a generic, non-template-derived object.
  # You cannot have a template with this name!
  GENERIC_OBJECT_TYPENAME = "generic".freeze

  # Ruby Struct representing a single page for a generic map object.
  # Instances have the following attributes:
  #
  # [number]
  #   The 0-based page number.
  # [graphic]
  #   A Pathname instance relative to the project
  #   root’s <tt>data/resources/graphics</tt> directory.
  #   Uses forward slashes / as path separator on any
  #   platform. If you assign a string to this, it will
  #   automatically converted to a Pathname for you.
  # [trigger]
  #   One of the following symbols (if you assign a string,
  #   it will automatically be converted for you):
  #   [:activate]
  #     The player needs to explicitely press a key
  #     to execute the code.
  #   [:immediate]
  #     The code is executed immediately when the map
  #     has finished loading.
  #   [:none]
  #     The code cannot be executed at all. Useful for
  #     purely-graphical stuff.
  # [code]
  #   A string containing the executable Ruby code for
  #   this page.
  class Page < Struct.new(:number, :graphic, :trigger, :code)

    def initialize(*)
      super
      self.graphic ||= Pathname.new("")
      self.trigger ||= :none
      self.code    ||= ""
    end

    def trigger=(val)
      # This case statement circumvents #to_sym which
      # would otherwise be necessary for conversion here.
      case val.to_s
      when "activate"  then super(:activate)
      when "immediate" then super(:immediate)
      when "none"      then super(:none)
      else
        raise(ArgumentError, "Invalid trigger `#{val}'!")
      end
    end

    def graphic=(val)
      super(Pathname.new(val))
    end

  end

  # The underlying TiledTmx::Object.
  attr_reader :tmx_object

  # Format the given object ID the way it should be
  # presented to the user and is used for name generation.
  def self.format_object_id(id)
    sprintf("0x%08x", id)
  end

  # Create a MapObject from a TiledTmx::Object. Any modifications
  # you make to the MapObject will automatically be propagated
  # to the TiledTmx::Object.
  #
  # If +tmx_obj+ is already a MapObject instance, it will
  # just be returned.
  def self.from_tmx_object(tmx_obj)
    # If we already get a MapObject, we just return it.
    return tmx_object if tmx_obj.kind_of?(self)

    obj = allocate
    obj.instance_variable_set(:@tmx_object, tmx_obj)
    obj
  end

  # Create a MapObject from a Backend::Template by specializing it
  # with the given parameters.
  # == Parameters
  # [template]
  #   The Backend::Template instance to construct the object from.
  # [page_params = []]
  #   The parameters to pass to the template per-page. See
  #   Backend::Template#result for the exact format of this.
  # == Return value
  # The constructed MapObject instance.
  # == Remarks
  # * Changing MapObject instances created by this method is
  #   not possible beyond changing the parameter values, because
  #   objects constructed by means of templates don’t have their
  #   "own" code and properties, they use those of the template.
  # * The template doesn’t get stenciled-out here, i.e. no code
  #   will be generated by applying +page_params+. This is left
  #   to the game engine, so that we can properly change the
  #   parameter values after the call to this method.
  def self.from_template(template, page_params = [])
    obj = allocate
    obj.instance_eval do
      @tmx_object.type   = template.name   # This is not a generic event
      @tmx_object.width  = template.width  # FIXME: This may get...
      @tmx_object.height = template.height # ...out of sync if the template is changed

      page_params.each_with_index do |params, index|
        @tmx_object.properties["templateparams-#{index}"] = params.to_json # FIXME: This should be nested XML, but the TMX format doesn’t allow this
      end
    end

    obj
  end

  # Create a new MapObject you can later on feed into Map#add_object.
  # The underlying TiledTmx::Object is automatically created for you.
  # Any arguments are forwarded to TiledTmx::Object.new.
  def initialize(*args)
    @tmx_object = TiledTmx::Object.new(*args)
    @tmx_object.type = GENERIC_OBJECT_TYPENAME
  end

  # Two MapObjects are considered equal if they refer to the
  # same underlying +tmx_object+.
  def eql?(other)
    return nil unless other.respond_to?(:tmx_object)

    @tmx_object == other.tmx_object
  end
  alias == eql?

  ##
  # :method: name
  # Delegates.

  ##
  # :method: type
  # Delegates.

  ##
  # :method: gid
  # Delegates.

  ##
  # :method: x
  # Delegates.

  ##
  # :method: y
  # Delegates.

  ##
  # :method: name=
  # Delegates.

  ##
  # :method: x=
  # Delegates.

  ##
  # :method: y=
  # Delegates.

  ##
  # :method: gid=
  # Delegates.

  ##
  # :method: properties
  # Delegates.

  # TiledTmx::Object delegators
  [:name, :type, :gid, :x, :y, :name=, :x=, :y=, :gid=, :properties].each do |sym|
    define_method(sym) do |*args|
      @tmx_object.send(sym, *args)
    end
  end

  # The width of this map object, in pixels.
  def width
    @tmx_object.width
  end

  # Delegates to TiledTmx::Object#width=.
  # Raises a TypeError if this is not a generic object.
  def width=(val)
    generic! # Width determined by template on saving
    @tmx_object.width = val
  end

  # The height of this map object, in pixels.
  def height
    @tmx_object.height
  end

  # Delegates to TiledTm::Object#height=.
  # Raises a TypeError if this is not a generic object.
  def height=(val)
    generic! # Height determined by template on saving
    @tmx_object.height = val
  end

  # Add a new page to the map object.
  # == Parameters
  # [page (nil)]
  #   The Page instance to add. If this is +nil+, a new
  #   page will automatically be created for you.
  # [page (block)]
  #   The Page instance you added.
  # == Raises
  # [TypeError]
  #   This is not a generic map object.
  # == Remarks
  # The page number is set automatically to the next consecutive
  # page number if +page+ is +nil+.
  def add_page(page = nil)
    generic!

    page ||= Page.new(pages.count)
    yield(page) if block_given?

    # Note we rely on two autoconversions of #to_json:
    #  1. Symbols are converted to strings.
    #  2. Pathnames are converted to strings.
    @tmx_object.properties["page-#{page.number}"] = page.to_h.to_json # FIXME: This should be nested XML, but the TMX format doesn’t allow this
  end

  # Delete a page from the map object.
  # == Parameters
  # [n]
  #   The number of the page you want to delete.
  # == Raises
  # [TypeError]
  #   This is not a generic map object.
  # == Remarks
  # Other pages’ numbers won’t be affected by this, i.e. this
  # method creates a gap.
  def delete_page(n)
    generic!

    @tmx_object.properties.delete("page-#{n}")
  end

  # Returns the pages for this map object.
  # == Return value
  # For generic map objects, an array of Page instances. For
  # non-generic map objects, you instead receive an array
  # of OpenRubyRMK::Backend::Template::TemplatePage instances.
  # == Remarks
  # The returned array is recursively frozen, i.e. you can’t modify
  # it. The reasoning for this is that you would be required to
  # also modify the underlying +tmx_object+ accordingly otherwise,
  # which is done by the #add_page and #delete_page methods. As for
  # template pages, you have to modify the template itself anyway.
  def pages
    if generic?
      result = []

      @tmx_object.properties.each do |k, v|
        if k =~ /^page-\d+$/
          hsh          = JSON.parse(v) # FIXME: This should be nested XML, but the TMX format doesn’t allow this
          page         = Page.new
          page.number  = $1.to_i
          page.graphic = hsh["graphic"]
          page.trigger = hsh["trigger"]
          page.code    = hsh["code"]
          page.freeze # Can’t modify them, because we would need to update the JSON

          result << page
        end
      end

      result.sort_by(&:number).freeze # Can’t modify, see above
    else
      result = Marshal.load(Marshal.dump(@template.pages)) # Deep copy
      result.map(&:freeze)
      result.freeze

      result
    end
  end

  # True if this is a generic, i.e. not-templated-created, map object.
  def generic?
    @tmx_object.type == GENERIC_OBJECT_TYPENAME
  end

  # True if this is not a generic, i.e. a templated-created, map object.
  def templated?
    !generic?
  end

  # Modify the template parameters used to evaluate the template
  # this map object is based on.
  # == Parameters
  # [page_params]
  #   An array of hashes describing the parameters you want to
  #   update. See Template#result for a description of the format.
  # == Raises
  # [TypeError]
  #   This is not a template-based map object.
  def modify_params(page_params)
    templated!

    page_params.each_with_index do |params, index|
      if @tmx_object.properties["templateparams-#{index}"]
        current_params = JSON.parse(@tmx_object.properties["templateparams-#{index}"]) # FIXME: This should be nested XML, but the TMX format doesn’t allow this
      else
        current_params = {}
      end

      current_params.update(params)
      @tmx_object.properties["templateparams-#{index}"] = current_params.to_json # FIXME: This should be nested XML, but the TMX format doesn’t allow this
    end
  end

  # Returns the parameters for a templated object as an
  # array of hashes (see Template#result for a description
  # of the format).
  # == Return value
  # As described.
  # == Remarks
  # The resulting array can’t be modified, because the underlying
  # TMX object has to be changed accordingly. Use #modify_params
  # in order to modify the parameters.
  def params
    templated!

    ary = []
    0.upto(Float::INFINITY) do |i|
      str = @tmx_object.properties["templateparams-#{i}"]
      if str
        ary << JSON.parse(str) # FIXME: This should be nested XML, but the TMX format doesn’t allow this
      else
        break
      end
    end

    ary.freeze
    ary
  end

  # Returns the map-unique ID of this MapObject, i.e.
  # the TMX +name+.
  def id
    @tmx_object.name.to_i # This is stored as a string in TMX
  end

  # Returns the map-unique ID of this MapObject the
  # way it should be presented to the user.
  def formatted_id
    self.class.format_object_id(id)
  end

  # Returns the custom, changable name for this object.
  def custom_name
    @tmx_object.properties["_name"]
  end

  # Set the custom, changable name for this object.
  def custom_name=(str)
    @tmx_object.properties["_name"] = str.to_str
  end

  private

  # Raises a TypeError if this object has been created by
  # means of ::from_template, i.e. its type is not :generic.
  def generic!
    unless generic?
      raise(TypeError, "Cannot change map objects that are not :generic (this object: :#{@tmx_object.type}). This mostly applies to template-generated objects.")
    end
  end

  # Raises a TypeError if this object has not been created
  # by means of ::from_template, i.e. its type is :generic.
  def templated!
    unless templated?
      raise(TypeError, "Cannot change map objects that are :generic (this object: #{@tmx_object.type}). This means you cannot call this on non-template-generated objects.")
    end
  end

end
