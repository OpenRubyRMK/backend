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
#   chest = Template.new do
#     parameter :item,  :type => :string
#     parameter :count, :type => :number, :default => 1
#
#     code <<-CODE
#       %{count}.times do
#         $player.items << Item[%{item}]
#       end
#     CODE
#   end
#
# As can be seen, the individual parameters can be substituted
# into the template by means of %{nameoftheparameter}.
class OpenRubyRMK::Backend::Template

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

  # The parameters this template wants. An array of Parameter instances.
  attr_reader :parameters

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
  def initialize(name, &block)
    @name       = name
    @parameters = []
    @code       = ""

    if block
      if block.arity == 1
        yield(self)
      else
        instance_eval(&block)
      end
    end
  end

  # Evaluate the template with the given parameter hash.
  # The parameters for this hash correspond to the parameters
  # you defined for this template via the #parameter method;
  # default values will automatically jump in if you ommit an
  # optional parameter.
  # Returns the stenciled-out code as a string.
  def result(params)
    params = params.recursively_stringify_keys
    hsh = {}

    # Note the use of #has_key? as the value may be explicitely +nil+.
    @parameters.each do |para|
      raise(ArgumentError, "Required parameter `#{para.name}' missing!") if para.required? && !params.has_key?(para.name)
      hsh[para.name] = params.has_key?(para.name) ? params[para.name] : para.default_value
    end

    sprintf(code, hsh)
  end

  # Define a parameter for the template.
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
    @parameters << param
  end

  # Get or set the code template for the parameter. If
  # +str+ is given, sets the template, otherwise, returns it.
  def code(str = nil)
    return @code unless str # Getter

    @code = str
  end

  # Set the code template to +str+.
  def code=(str)
    @code = str
  end

end
