# Mixin module granting a method #property akin to +attr_accessor+, except
# it allows the DSL-like setting of the instance variable by means of passing
# an argument to the "getter" method:
#
#   class Thing
#     extend Properties
#
#     property :color
#   end
#
#   t = Thing.new
#   t.color :red
#   p t.color #=> :red
#
# This is especially useful for objects to be used in DSLs.
#
# Note this module is intended to be *extended* into a class,
# not *included*.
module OpenRubyRMK::Backend::Properties

  # Defines two methods: +name+ and <tt>name=</tt>. The first
  # can be used to both retrieve and set an instance variable
  # of name <tt>@name</tt> (see the introduction), the second
  # one can only be used to set the instance variable.
  def property(name, hsh = {})
    ivar            = :"@#{name}"
    hsh[:default] ||= nil

    # Combined Getter/Setter
    define_method(name) do |*args|
      if args.count.zero?
        # If the variable is unset, set it with the default
        # (which may also be a Proc that is to be called).
        unless instance_variable_defined?(ivar)
          default = hsh[:default].respond_to?(:call) ? hsh[:default].call : hsh[:default]
          instance_variable_set(ivar, default)
        end

        instance_variable_get(ivar)
      elsif args.count == 1
        instance_variable_set(ivar, args.first)
      else
        raise(ArgumentError, "Wrong number of parameters, expected 0..1, got #{args.count}")
      end
    end

    # Setter
    define_method(:"#{name}=") do |arg|
      instance_variable_set(ivar, arg)
    end

    # If you ever choose this as a class ivar name in an including
    # class... you know.
    @__hopefully_not_colliding_ivar_name_properties ||= []
    @__hopefully_not_colliding_ivar_name_properties << name.to_sym
    # Thinking about it, one could add some _ to the end of the name,
    # just to be sure.
  end

  # Returns the names of the defined properties (without
  # an @ sign, in the order you called the #property method).
  def properties
    @__hopefully_not_colliding_ivar_name_properties
  end

end
