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
#           $player.items << Item["%{item}"]
#         end
#       CODE
#     end
#   end
#
# As can be seen, the individual parameters can be substituted
# into the template by means of %{nameoftheparameter}. If you
# want a raw percent sign, use %%.
#
# To evaluate this template, do the following:
#
#  chest.result([
#    {:count => 3, :item => "banana"}
#  ]) do |page, result|
#    eval(result)
#  end
#
# The Template#result method takes an array of hashes,
# where each hash carries the values for the parameters
# of the page its position in the array corresponds to,
# i.e. the hash with index 0 will be used for page 0,
# etc.
class OpenRubyRMK::Backend::Template

  # A single page inside a template. It encapsulates
  # a defined number of parameters which can finally
  # be referenced inside the code part of the page.
  # Each parameter has a name and a type, and possibly
  # a default value (+nil+ is used if you ommit the
  # default).
  class TemplatePage
    extend OpenRubyRMK::Backend::Properties

    ##
    # Page number. Ensure it really corresponds to
    # the array index of the page in the Template#pages
    # array.
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

  # Hash used to convert the default values for parameters from
  # XML (where they always are strings) to a useful Ruby value.
  PARAMETER_TYPE_CONVERSIONS = {
    :string  => lambda{|para| para.to_s},
    :number  => lambda{|para| para.to_i},
    :boolean => lambda{|para| para == "true"}
  }

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

  # Escapes +str+ in a way that it should be usable as a valid
  # filename on most operating systems. Returns a new string.
  def self.escape_filename(str)
    str.gsub(/[[:punct:]]/, "").gsub(/[[:space:]]/, "_")
  end

  def self.from_file(path)
    template = allocate
    template.instance_eval do
      template_node = Nokogiri::XML(File.open(path)).root

      @name   = template_node["name"]
      @width  = template_node["width"].to_i
      @height = template_node["height"].to_i
      @pages  = []

      template_node.xpath("pages/page").each do |page_node|
        page         = TemplatePage.new(page_node["number"].to_i)
        page.graphic = page_node.xpath("graphic").text.strip.empty? ? nil : page_node.xpath("graphic").text.strip
        page.trigger = page_node.xpath("trigger").text.strip.empty? ? nil : page_node.xpath("trigger").text.strip.to_sym
        page.code    = page_node.xpath("code").text.strip

        page_node.xpath("parameters/parameter").each do |para_node|
          type = para_node["type"].to_sym
          default = para_node["default_value"].strip

          page.parameter(para_node["name"],
                         :type => type,
                         :default => default.empty? ? nil : PARAMETER_TYPE_CONVERSIONS[type].call(default))
        end

        @pages << page
      end
    end

    template
  end

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
  #   eql?(other) → true, false, nil
  #   self == other → true, false, nil
  #
  # Compares two templates. Two templates are considered equal
  # if they have the same #name.
  def eql?(other)
    return nil unless other.respond_to?(:name)
    @name == other.name
  end
  alias == eql?

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

  def save(templates_dir)
    b = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.template(:name => @name, :width => @width, :height => @height) do |template_node|

        template_node.pages do |pages_node|
          @pages.each do |page|
            pages_node.page(:number => page.number) do |page_node|
              page_node.graphic(page.graphic)
              page_node.trigger(page.trigger)
              page_node.code(page.code)

              page_node.parameters do |paras_node|
                page.parameters.each do |para|
                  paras_node.parameter(:name => para.name, :type => para.type, :default_value => para.default_value)
                end #each
              end # </parameters>

            end # </page>
          end #each
        end # </pages>

      end # </template>
    end #new

    target = Pathname.new(templates_dir).join("#{self.class.escape_filename(@name)}.xml")
    target.open("w"){|file| file.write(b.to_xml)}
    target
  end

end
