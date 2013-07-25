# -*- coding: utf-8 -*-

# Templates describe map events that are not yet "finished", i.e. that have
# a number of parameters that have to be substituted later. They are used to
# define for instance what exactly makes up a teleporter or a chest event in
# a way that doesn’t require the user to always use a generic event and re-type
# again and again the same code to create for example a simple chest. Instead,
# define a template and for each chest you want simply pass in the parameters
# that actually differ between your chests (i.e. the item and item count).
#
# The "chest" template may look like this:
#
#   chest = Template.new "chest" do
#     # Like "real" events, templates can have multiple pages.
#     # Call #page as often as you need it; the pages are numbered
#     # from 0 on upwards if you need to refer to them.
#     page do
#       parameter :item,  :type => :string
#       parameter :count, :type => :number, :default => 1
#
#       code <<-CODE
#         %{count}.times do
#           $player.items << Item[%{item}]
#         end
#       CODE
#     end
#   end
#
# As can be seen, the individual parameters can be substituted
# into the template by means of %{nameoftheparameter}.
class OpenRubyRMK::Backend::Template

  class TemplatePage
    extend OpenRubyRMK::Backend::Properties

    ##
    # Page number.
    property :number

    ##
    # Graphic.
    property :graphic

    ##
    # Trigger of the page. One of: :activate, :immediate
    property :trigger,    :default => :activate

    ##
    # Code of the page, as a string. Use %{parametername} to
    # substitute a parameter value.
    property :code,       :default => proc{""} # Prevent byref!

    ##
    # List of Parameter instances for this page.
    property :parameters, :default => proc{[]} # Prevent byref!

    # Create a new TemplatePage, passing the
    # page number.
    def initialize(pagenum)
      @number = pagenum
    end

    # Define a parameter for the page.
    # == Parameters
    # [name]
    #   The parameter’s name.
    # [opts]
    #   A hash taking the following parameters
    #   [type]
    #     The parameter’s type.
    #     FIXME: Which types are supported?
    #   [default]
    #     The default value if the parameter is not given.
    #     If this is ommitted, the parameter will automatically
    #     be marked as required.
    def parameter(name, opts)
      raise(ArgumentError, "No :type given") unless opts[:type]

      param = Parameter.new(name.to_s, opts[:type], !opts[:default], opts[:default])
      parameters << param
    end

    # Stencils out the template code with the given parameters.
    # == Parameters
    # [params ({})]
    #   A hash of parameters, as defined by the calls to #parameter.
    # == Raises
    # [ArgumentError]
    #   If a required parameter is missing.
    # == Return value
    # The resulting code as a string.
    def result(params = {})
      params = params.recursively_stringify_keys
      hsh    = {}

      # Note the use of #has_key? as the value may be explicitely +nil+.
      parameters.each do |para|
        raise(ArgumentError, "Required parameter `#{para.name}' missing for page ##@number!") if para.required? && !params.has_key?(para.name)
        hsh[para.name] = params.has_key?(para.name) ? params[para.name] : para.default_value
      end

      sprintf(code, hsh.recursively_symbolize_keys) # FIXME: https://bugs.ruby-lang.org/issues/8688
    end

  end

  # This struct describes a single parameter by name and type.
  # If +required+ is set, the +default_value+ *must* be ignored
  # and an exception must be raised if that parameter is missing
  # on evaluation.
  Parameter = Struct.new(:name, :type, :required, :default_value) do
    def required? # :nodoc:
      required
    end
  end

  # The name of the template, as a string.
  attr_reader :name
  # The width of the object, in pixels.
  attr_reader :width
  # The height of the object, in pixels.
  attr_reader :height
  # List of TemplatePage instances for this template.
  attr_reader :pages

  # call-seq:
  #   new( name ) → template
  #   new( name ){...} → template
  #   new( name ){|template| ... } → template
  #
  # Create a new template. If called with a block without arguments,
  # the block is evaluated in the context of the new template; if
  # the block requires an argument, the block’s context won’t be
  # touched and it receives +self+ as the sole argument.
  # == Parameters
  # [name]
  #   The name of the template. Some kind of string you can remember.
  # [width (Map::DEFAULT_TILE_EDGE)]
  #   The width of this object, in pixels. This should be as large
  #   as the width of your widest graphic used in your pages.
  #   Graphics wider than this will be *cut off*.
  # [height (Map::DEFAULT_TILE_EDGE)]
  #   The height of this object, in pixels. This should be as large
  #   as the height of your tallest graphic used in your pages.
  #   Graphics taller than this will be *cut off*.
  # [template (block)]
  #   self.
  # == Return value
  # The newly created template.
  # == Examples
  # t = Template.new("thing")
  # t.parameter(:para1, type: :string)
  #
  # t = Template.new("thing") do
  #   parameter :para1, :type => :string
  # end
  #
  # t = Template.new("thing") do |template|
  #   template.parameter(:para1, type: :string)
  # end
  def initialize(name, width = OpenRubyRMK::Backend::Map::DEFAULT_TILE_EDGE, height = OpenRubyRMK::Backend::Map::DEFAULT_TILE_EDGE, &block)
    @name   = name
    @width  = width
    @height = height
    @pages  = []

    if block
      if block.arity == 1
        yield(self)
      else
        instance_eval(&block)
      end
    end
  end

  # call-seq:
  #   result(page_params){|page, result| ...}
  #
  # Evaluate the template with the given parameter-page array.
  # == Parameters
  # [page_params ([])]
  #   An array of hashes like this:
  #     [{:para1 => "value", :para2 => "value"}, {:para1 => "value"}]
  #   The index in the array corresponds to the page number, i.e.
  #   the page with number 2 will get the hash at index 2! (Note the
  #   first page number is 0.)
  # [page (block)]
  #   The TemplatePage we’re currently evaluating.
  # [result (block)]
  #   The stenciled-out code for this page (this is the
  #   result of TemplatePage#result if you want to know more).
  # == Raises
  # [ArgumentError]
  #   If any required parameter on any page is missing.
  def result(page_params = [])
    @pages.each do |page|
      yield(page, page.result(page_params[page.number]))
    end
  end

  # call-seq:
  #   page(){...}
  #   page(){|page| ...}
  #
  # Constructs a new page and appends it to the list of pages for
  # this template.
  # == Parameters
  # [page (block)]
  #   The TemplatePage instance.
  # == Remarks
  # The TemplatePage instance’s +number+ attribute is prefilled
  # for you (it is set to the next required page number).
  def page(&block)
    page = TemplatePage.new(pages.count)

    if block.arity.zero?
      page.instance_eval(&block)
    else
      yield(page)
    end

    @pages << page
  end

end
