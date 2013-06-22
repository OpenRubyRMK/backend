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
class OpenRubyRMK::Backend::MapObject

  # A single page for a generic map object.
  Page = Struct.new(:number, :graphic, :trigger, :code)

  # The underlying TiledTmx::Object.
  attr_reader :tmx_object
  # The underlying OpenRubyRMK::Backend::Template, if any.
  # +nil+ otherwise.
  attr_reader :template

  # Create a MapObject from a TiledTmx::Object. Any modifications
  # you make to the MapObject will automatically be propagated
  # to the TiledTmx::Object.
  def self.from_tmx_object(tmx_obj)
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
      @tmx_object.type = template.name # This is not a generic event

      page_params.each_with_index do |params, index|
        @tmx_object.properties["templateparams-#{index}"] = params.to_json # FIXME: This should be nested XML, but the TMX format doesn’t allow this
      end

      @template = template
    end

    obj
  end

  # Create a new MapObject you can later on feed into Map#add_object.
  # The underlying TiledTmx::Object is automatically created for you.
  def initialize
    @tmx_object = TiledTmx::Object.new
    @template   = nil
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

  # TiledTmx::Object delegators
  [:name, :type, :gid, :x, :y, :name=, :x=, :y=, :gid=].each do |sym|
    define_method(sym) do
      @tmx_object.send(sym)
    end
  end

  # The width of this map object, in pixels.
  def width
    if generic?
      @tmx_object.width
    else
      @template.width
    end
  end

  # Delegates to TiledTmx::Object#width=.
  # Raises a TypeError if this is not a generic object.
  def width=(val)
    generic! # Width determined by template on saving
    @tmx_object.width = val
  end

  # The height of this map object, in pixels.
  def height
    if generic?
      @tmx_object.height
    else
      @template.height
    end
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
          page = Page.new($1.to_i, JSON.parse(v)) # FIXME: This should be nested XML, but the TMX format doesn’t allow this
          page.freeze # Can’t modify them, because we would need to update the JSON
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
    @tmx_object.type == "generic"
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
      current_params = JSON.parse(@tmx_object.properties["templateparams-#{index}"]) # FIXME: This should be nested XML, but the TMX format doesn’t allow this
      current_params.update(params)
      @tmx_object.properties["templateparams-#{index}"] = current_params.to_json # FIXME: This should be nested XML, but the TMX format doesn’t allow this
    end
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
