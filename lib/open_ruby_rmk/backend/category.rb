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
#Category::Entry#[] and Category::Entry[]= methods which
#will convert both attribute names and values to strings
#automatically, because this information will be exported
#to XML which doesn’t know anbout anything else.
#
#==Example
#  # Create the new category
#  items = Category.new("items")
#
#  # Add one entry to the items category
#  item1 = Category::Entry.new
#  item1[:name] = "Hot thing"
#  item1[:type] = "fire"
#  items.entries << item1
#
#  # Add another item
#  item2 = Category::Entry.new
#  item2[:name] = "Cool thing"
#  item2[:type] = "ice"
#  items.entries << item2
#
#  # Add another item using hash
#  items << {:name => "Dirty thing", :type => "earth" }
#
#  # Attributes used in this category
#  # TODO: Enforce the same attributes for every entry
#  p items.attributes #=> ["name", "type"]
#
#  # Save it out to disk
#  items.save("items.xml")
#  # Reload it
#  items = Category.load("items.xml")
#  p items.entries.count #=> 2
#==Sample XML
#  <category>
#    <entry>
#      <attribute name="name">Hot thing</attribute>
#      <attribute name="type">fire</attribute>
#    </entry>
#    <entry>
#      <attribute name="name">Cool thing</attribute>
#      <attribute name="type">ice</attribute>
#    </entry>
#  </category>
class OpenRubyRMK::Backend::Category
  include Enumerable

  #Thrown when you try to create an entry with an attribute
  #not allowed in the entry’s category.
  class UnknownAttribute < StandardError # TODO: Proper exception hierarchy

    # The category you wanted to add the errorneous entry to.
    attr_reader :category
    # The entry containing the errorneous attribute.
    attr_reader :entry
    #The name of the errorneous attribute.
    attr_reader :attribute_name

    # Create a new exception of this class.
    # ==Parameters
    # [category]
    #   The entry’s target category.
    # [entry]
    #   The problematic entry.
    # [attr]
    #   The name of the faulty attribute.
    # [msg (nil)]
    #   Your custom error message.
    # ==Return value
    # The new exception.
    def initialize(category, entry, attr, msg = nil)
      super(msg || "The attribute #{attr} is not allowed in the #{category} category.")
      @category       = category
      @entry          = entry
      @attribute_name = attr
    end

  end

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

    #Gets the value of the named attribute. +name+ will
    #be converted to a string and the return value also
    #is a string.
    def [](name)
      @attributes[name.to_s]
    end

    # Sets the value of the named attribtue.
    # == Parameters
    # [name]
    #   The name of the parameter to set. Autoconverted
    #   to a string.
    # [val]
    #   The value to set it to. Autoconverted to a string.
    # == Raises
    # [UnknownAttribute]
    #   If this Entry has already been assigned to a category,
    #   and you try to set an attribute that isn’t allowed in
    #   that category, this exception will be raised.
    def []=(name, val)
      begin
        @attributes[name.to_s] = val.to_s
        @category.check_attributes!(self) if @category
      rescue UnknownAttribute
        # Ensure we clean up the entry, so that if the user rescues
        # this exception, the entry doesn’t have the attribute set
        # nevertheless.
        @attributes.delete(name.to_s)
        raise # reraise
      end
    end

    # Completely erases an attribute from the entry,
    # as opposed to setting it to +nil+ with #[]=
    # (what would effectively set it to an empty string).
    def delete(name)
      @attributes.delete(name.to_s)
    end
    alias delete_attribute delete

    # Checks whether this entry contains an attribute
    # of the given name. This is mostly used internally,
    # and you are advised to check a category’s allowed
    # attributes instead. +name+ is autoconverted to
    # a string.
    def include?(name)
      @attributes.has_key?(name.to_s)
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
      cat << self if cat && cat.include?(self)
      @category = cat
    end

  end

  #All attribute names allowed for entries in this
  #category.
  attr_reader :allowed_attributes
  #All Entry instances associated with this category.
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

      @name               = category_node["name"]
      @allowed_attributes = []
      @entries            = []

      category_node.xpath("entry").each do |entry_node|
        entry = Entry.new
        entry_node.xpath("attribute").each do |attr_node|
          add_attribute(attr_node["name"]) # NOP if already in
          entry[attr_node["name"]] = attr_node.text
        end
        add_entry(entry)
      end
    end

    cat
  end

  #Create a new and empty category.
  def initialize(name)
    @name               = name.to_str
    @allowed_attributes = Set.new
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

  #Iterates over each Entry in this Category.
  def each(&block)
    @entries.each(&block)
  end

  # Checks whether +name+ is a valid attribute for entries
  # in this category.
  # == Parameter
  # [name] The attribute name to check. Autoconverted to a string.
  # == Return value
  # Either true or false.
  def valid_attribute?(name)
    @allowed_attributes.include?(name.to_s)
  end

  # Checks whether +entry+ is valid in the context in this
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

  # Add a new attribute to each entry in this category.
  # == Parameter
  # [name]
  #   The name of the attribute you want to add.
  #   Autoconverted to a string.
  # == Rermarks
  # * The already existing entries will have this attribute
  #   set to an empty string.
  # * If the attribute is already allowed, does nothing.
  def add_attribute(name)
    name = name.to_s
    return if valid_attribute?(name)

    @allowed_attributes << name.dup.freeze
    @entries.each do |entry|
      entry[name] = nil # Autoconverted to an empty string
    end
  end

  #Removes an attribute (plus value) from each entry
  #in this category.
  #If this attribute wasn’t existant before, does nothing.
  def delete_attribute(name)
    name = name.to_s
    return unless valid_attribute?(name)

    @allowed_attributes.delete(name)
    @entries.each do |entry|
      entry.delete(name)
    end
  end

  # call-seq:
  #   each_allowed_attribute             → an_enumerator
  #   each_allowed_attribute{|name| ...} → self
  #
  # Iterates over all allowed attribute names, which are passed
  # to the block as strings. Returns an enumerator if no block
  # is given.
  def each_allowed_attribute(&block)
    return to_enum(__method__) unless block_given?
    @allowed_attributes.each(&block)
    return self
  end

  # Deletes an entry from this category. The entry has assigned
  # +nil+ as the category afterwards.
  # If +entry+ doesn’t belong to this category, does nothing.
  def delete(entry)
    return unless @entries.include?(entry)
    @entries.delete(entry)
    entry.category = nil
  end

  # Saves a category out to disk, in the given
  # directory. The filename is the base64-encoded
  # +name+ of the category.
  def save(categories_dir)
    b = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.category do |cat_node|
        @entries.each do |entry|
          cat_node.entry do |entry_node|
            entry.each_attribute do |att_name, att_val|
              entry_node.attribute(att_val, :name => att_name)
            end # each_attribute
          end #</entry>
        end #each entry
      end #</category>
    end # Builder.new

    target = Pathname.new(categories_dir).join("#{self.class.generate_file_id}.xml")
    target.open("w"){|file| file.write(b.to_xml)}
    target
  end

end
