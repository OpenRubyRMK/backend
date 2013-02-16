# -*- coding: utf-8 -*-

#A _category_ encapsulates all information from a special
#kind of resource in the ORR. These resources include
#items, weapons, skills and everything else that occurs
#in a great number with configurable subattributes.
#
#For example, the (predefined) category _items_ (represented
#by an instance of this class) holds a list of items defined
#by the user. Each item in this category has a specific number
#of attributes (i.e. each item has the *same* attributes, but
#most likely with different values assigned to them) and is
#represented by an instance of class Cagegory::Entry. Finally,
#the items’ attributes can be accessed by means of the
#Category::Entry#[] and Category::Entry[]= methods.
#
#==Example
#  # Create the new category
#  items = Category.new("items")
#
#  # Define the attributes allowed in this category
#  items.define_attribute(:name, :type => :string, :description => "The name of the item")
#  items.define_attribute(:type, :type => :symbol, :description => "The elementary type of the item")
#
#  # Add one entry to the items category
#  item1 = Category::Entry.new
#  item1[:name] = "Hot thing"
#  item1[:type] = :fire
#  items.entries << item1
#
#  # Add another item
#  item2 = Category::Entry.new
#  item2[:name] = "Cool thing"
#  item2[:type] = :ice
#  items.entries << item2
#
#  # Add another item using hash
#  items << {:name => "Dirty thing", :type => :earth}
#
#  # Attributes used in this category
#  p items.allowed_attributes.keys #=> [:name, :type]
#
#  # Save it out to disk
#  path = items.save("/tmp/categories")
#  # Reload it
#  items = Category.load(path)
#  p items.entries.count #=> 2
#
#==Sample XML
#  <category name="skills">
#    <!-- Definition of allowed entries -->
#    <definitions>
#      <definition name="name">
#        <type>string</type>
#        <description>
#          The name of the skill.
#        </description>
#      </definition>
#      <definition name="damage">
#        <type>float</type>
#        <description>
#          The damage multiplicator for this
#          skill, as a floating-point number.
#        </description>
#      </definition>
#    </definitions>
#
#    <!-- Actual entries -->
#    <entries>
#      <entry>
#        <attribute name="name">Hot thing</attribute>
#        <attribute name="damage">3.2</attribute>
#      </entry>
#      <entry>
#        <attribute name="name">Cool thing</attribute>
#        <attribute name="damage">10.3</attribute>
#      </entry>
#    </entries>
#  </category>
class OpenRubyRMK::Backend::Category
  include Enumerable
  include OpenRubyRMK::Backend::Errors

  # Provides the type converters for the attribute
  # values. This hash maps each allowed attribute
  # type to a lambda which converts the string value
  # found in the XML to an actually useful Ruby type.
  ATTRIBUTE_TYPE_CONVERSIONS = {
    :number => lambda{|str| str.to_i},
    :float  => lambda{|str| str.to_f},
    :symbol => lambda{|str| str.to_sym},
    :string => lambda{|str| str} # No conversion at all
  }

  # This is a metadata object that holds information about
  # attributes like what type an attribute must have
  # (especially useful for deserializing from XML). You
  # most likely don’t have to use this directly.
  AttributeDefinition = Struct.new(:type, :description)

  # This class represents a single entry in a category. It may
  # have several attributes (accessible via #[] and #[]=), and
  # initially doesn’t belong to a category. Using the
  # Category#add_entry and Category#<< methods, you can do so,
  # which will automatically prevent the Entry instance from
  # reaching states that are invalid within the context of the
  # category it is assigned to. For instance, if a category "items"
  # doesn’t allow for an attribute "grow_rate", you can set this
  # attribute on your entry nevertheless, as long as you don’t assign
  # the entry to this particular category. If you do so, you will
  # receive an exception; either allow the attribute in the Category
  # instance (using Category#allow_attribute), or change the Entry.
  # You can always check the category an entry is assigned to by use
  # of the #category accessor.
  class Entry

    ##
    # :attr_accessor: category
    # The Category instance this entry belongs to,
    # if any. Before assigning an entry to a category,
    # this is +nil+. This value is managed automatically
    # for you, so you most likely don’t need to change it
    # using this accessor (but if you have to, it is save).

    #Creates a new and empty entry.
    #==Parameter
    #[hsh ({})] Set some attributes on the entry directly
    #           while creating it. The semantics are the
    #           same as for the #[]= method.
    #==Return value
    #The new instance.
    def initialize(hsh = {})
      @attributes = Hash.new{|h, k| h[k] = ""}
      @category   = nil

      hsh.each {|k,v| self[k] = v}
    end

    #Gets the value of the named attribute.
    def [](name)
      @attributes[name]
    end

    # Sets the value of the named attribtue.
    # == Parameters
    # [name]
    #   The name of the parameter to set.
    # [val]
    #   The value to set it to. Autoconverted to a string.
    # == Raises
    # [UnknownAttribute]
    #   If this Entry has already been assigned to a category,
    #   and you try to set an attribute that isn’t allowed in
    #   that category, this exception will be raised.
    def []=(name, val)
      begin
        @attributes[name] = val
        @category.check_attributes!(self) if @category
      rescue OpenRubyRMK::Backend::Errors::UnknownAttribute
        # Ensure we clean up the entry, so that if the user rescues
        # this exception, the entry doesn’t have the attribute set
        # nevertheless.
        @attributes.delete(name)
        raise # reraise
      end
    end

    # Completely erases an attribute from the entry,
    # as opposed to setting it to +nil+ with #[]=
    # (what would effectively set it to an empty string).
    def delete(name)
      @attributes.delete(name)
    end
    alias delete_attribute delete

    # Checks whether this entry contains an attribute
    # of the given name. This is mostly used internally,
    # and you are advised to check a category’s allowed
    # attributes instead. +name+ is autoconverted to
    # a string.
    def include?(name)
      @attributes.has_key?(name)
    end

    # call-seq:
    #   each_attribute                    → an_enumerator
    #   each_attribute{|name, value| ...} → self
    #
    # Iterates over all attribute names and values, which
    # are passed as strings to the block. If no block is
    # passed, returns an enumerator.
    def each_attribute(&block)
      return to_enum(__method__) unless block_given?
      @attributes.each_pair(&block)
      return self
    end

    # See accessor docs.
    def category # :nodoc:
      @category
    end

    # See accessor docs.
    def category=(cat) # :nodoc:
      return cat if @category == cat

      @category.delete(self) if @category
      cat << self if cat
      @category = cat
    end

  end

  # All attribute names allowed for entries in this
  # category. This is a hash mapping the attribute
  # names (symbols) to instances of AttribtueDefinition.
  attr_reader :allowed_attributes
  # All Entry instances associated with this category.
  attr_reader :entries
  alias :entries :to_a

  ##
  # :attr_accessor: name
  # The category’s name.

  ##
  # :method: to_a
  # Same as the #entries accessor.

  # Generates and returns a one-time file ID.
  # Only used when writing out the category files to
  # ensure they have unique filenames without having
  # to know anything about the other existing categories.
  # Don’t call this directly.
  def self.generate_file_id # :nodoc:
    @file_id ||= 0

    @file_id += 1
  end

  # Loads a Category from the file at the given path.
  # == Parameters
  # [path]
  #   The file to load from, either a string or a Pathname
  #   object. Note the filename is interpreted as a base-64-
  #   encoded string that will be the name of the category.
  def self.from_file(path) # :nodoc:
    cat = allocate
    cat.instance_eval do
      category_node = Nokogiri::XML(File.open(path)).root
      raise(ParseError.new(path, def_node.line, "No category name found in line #{category_node.line}")) unless category_node["name"]

      @name               = category_node["name"]
      @allowed_attributes = {}
      @entries            = []

      ### First parse all definitions ###
      category_node.xpath("definitions/definition").each do |def_node|
        raise(ParseError.new(path, def_node.line, "No attribute name found in line #{def_node.line}")) unless def_node["name"]
        definition = AttributeDefintion.new(def_node.xpath("type").text,
                                            def_node.xpath("description").text)
        raise(ParseError.new(path,
                             nil,
                             "No attribute type information found for attribute `#{def_node['name']}'")
              ) if definition.type.nil? || definition.type.empty?

        @allowed_attributes[def_node["name"].to_sym] = definition # This to_sym should be safe as its not arbitrary at runtime
      end

      ### Now retrieve all the attributes ###
      category_node.xpath("entries/entry").each do |entry_node|
        entry = Entry.new

        entry_node.xpath("attribute").each do |attr_node|
          name = attr_node["name"] || raise(ParseError.new(path, attr_node.line, "No attribute name found in line #{attr_node.line}"))
          raise(ParseError.new(path, attr_node.line, "Undefined attribute name `#{name}' in line #{attr_node.line}")) unless valid_attribute?(name)

          # Add the attribute, converting the string stored in XML
          # to whatever the attribute’s type definition demands.
          entry[name] = ATTRIBUTE_TYPE_CONVERSIONS[@allowed_attributes[name]][attr_node.text]
          add_entry(entry)
        end
      end
    end

    cat
  end

  # Create a new and empty category.
  # == Parameter
  # [name]
  #   The name of the category, as a string. May contain whitespace,
  #   but this is discouraged.
  # == Return value
  # The newly created instance.
  def initialize(name)
    @name               = name.to_str
    @allowed_attributes = {}
    @entries            = []
  end

  #See accessor.
  def name=(str) # :nodoc:
    @name = str.to_str
  end

  #See accessor.
  def name # :nodoc:
    @name
  end

  # Adds an Entry to this category.
  # == Parameter
  # [entry]
  #   The Entry instance to add; it will automatically be assigned
  #   this category. Alternatively, this can be a hash like the one
  #   Entry::new accepts; the Entry instance will be constructed
  #   implicitely for you and added to the category.
  # == Raises
  # [UnknownAttribute]
  #   If your entry contains an attribute that is not
  #   allowed in this category.
  def add_entry(entry)
    entry = Entry.new(entry) unless entry.is_a?(Entry)
    entry.category = self
    check_attributes!(entry)
    @entries.push(entry)
  end

  # Same as #add_entry, but returns +self+ for method
  # chaining.
  def <<(entry)
    add_entry(entry)
    self
  end

  # Deletes an entry from this category. The entry has assigned
  # +nil+ as the category afterwards.
  # If +entry+ doesn’t belong to this category, does nothing.
  def delete(entry)
    return unless @entries.include?(entry)
    @entries.delete(entry)
    entry.category = nil
  end

  #Iterates over each Entry in this Category.
  def each(&block)
    @entries.each(&block)
  end

  # Checks whether +name+ is a valid attribute for entries
  # in this category.
  # == Parameter
  # [name] The attribute name to check.
  # == Return value
  # Either true or false.
  def valid_attribute?(name)
    @allowed_attributes.has_key?(name)
  end

  # Add a new attribute definition to each entry in this category.
  # == Parameters
  # [name]
  #   The name of the attribute to allow, as a symbol.
  # [args]
  #   Either an instance of AttributeDefinition, or, more convenient,
  #   named arguments as follows:
  #   [:type]
  #     The type of the attribute, as a symbol.
  #   [:description]
  #     A short description of this attribute to inform the
  #     user what to put here. May be multiline.
  # == Raises
  # [DuplicateAttribute]
  #   If you try to define an attribute more than once.
  # == Rermarks
  # * The already existing entries will have this attribute
  #   set to an empty string.
  def define_attribute(name, args)
    raise(DuplicateAttribute.new(name) if valid_attribute?(name)
    definition = args.kind_of?(AttributeDefinition) ? args : AttributeDefinition.new(args)

    @allowed_attributes[name] = definition
    @entries.each do |entry|
      entry[name] = nil # Autoconverted to an empty string
    end
  end

  #Removes an attribute (plus value) from each entry
  #in this category and disallows it.
  #If this attribute wasn’t existant before, does nothing.
  def undefine_attribute(name)
    return unless valid_attribute?(name)

    @entries.each do |entry|
      entry.delete(name)
    end

    @allowed_attributes.delete(name)
  end

  # call-seq:
  #   each_allowed_attribute                         → an_enumerator
  #   each_allowed_attribute{|name, definition| ...} → self
  #
  # Iterates over all allowed attributes and their definitions
  # (instances of AttributeDefinition). If called without a
  # block, returns an enumerator.
  def each_allowed_attribute(&block)
    return to_enum(__method__) unless block_given?
    @allowed_attributes.each_pair{|name, definition| yield(name, definition)}
    return self
  end

  # Checks whether +entry+ (an Entry instance) is valid in the context of this
  # category. If it isn’t, raises an instance of UnknownAttribute,
  # otherwise does nothing; in any case, doesn’t alter the
  # state of neither the category nor the entry.
  # This is an internal method called when you modify entries in
  # categories.
  def check_attributes!(entry) # :nodoc:
    entry.each_attribute do |attr_name, attr_value|
      raise(UnknownAttribute.new(self, entry, attr_name)) unless valid_attribute?(attr_name)
    end
  end

  # Saves a category out to disk, in the given
  # directory. The filename is the base64-encoded
  # +name+ of the category.
  def save(categories_dir)
    b = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.category(:name => @name) do |cat_node|
        cat_node.definitions do |defs_node|
          @allowed_attributes.each_pair do |name, definition|
            defs_node.definition(:name => name) do |def_node|
              def_node.type(definition.type.to_s)
              def_node.description(definition.description.to_s) # May be nil
            end # </definition>
          end # each_pair
        end # </definitions>

        cat_node.entries do |entries_node|
          @entries.each do |entry|
            entries_node.entry do |entry_node|
              entry.attributes.each do |attr|
                entry_node.attribute(attr.value, :name => attr.name)
              end #each
            end #</entry>
          end #each
        end #</entries>

      end #</category>
    end # Builder.new

    target = Pathname.new(categories_dir).join("#{self.class.generate_file_id}.xml")
    target.open("w"){|file| file.write(b.to_xml)}
    target
  end

end
