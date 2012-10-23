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
  class UnknownAttribute < OpenRubyRMK::Errors::OpenRubyRMKError

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
      @entry          = entry
      @attribute_name = attr
    end

  end

  #An entry in a category.
  class Entry

    #All attributes (and their values) for this
    #entry. Don’t modify this directly, use the
    #methods provided by this class.
    attr_reader :attributes

    #Creates a new and empty entry.
    #==Return value
    #The new instance.
    def initialize
      @attributes = Hash.new{|hsh, k| hsh[k] = ""}
    end

    #Gets the value of the named attribute. +name+ will
    #be converted to a string and the return value also
    #is a string.
    def [](name)
      @attributes[name.to_s]
    end

    #Sets the value of the named attribtue. +name+
    #and +val+ will be converted to strings.
    def []=(name, val)
      @attributes[name.to_s] = val.to_s
    end

    #Iterates over all attribute names and values.
    def each_attribute(&block)
      @attributes.each_pair(&block)
    end

  end

  #All attribute names allowed for entries in this
  #category.
  attr_reader :allowed_attributes
  #All Entry instances associated with this category.
  attr_reader :entries

  ##
  # :attr_accessor: name
  #The category’s name.

  # Generates and returns a one-time file ID.
  # Only used when writing out the category files to
  # ensure they have unique filenames without having
  # to know anything about the other existing categories.
  def self.generate_file_id
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
        @entries << entry
      end
    end

    cat
  end

  #Create a new and empty category.
  def initialize(name)
    @name               = name.to_str
    @allowed_attributes = []
    @entries            = []
  end

  #See accessor.
  def name=(str) # :nodoc:
    @name = str.to_str
  end

  #See accessor.
  def name
    @name
  end

  # Adds an Entry to this category.
  # == Raises
  # [UnknownAttribute]
  #   If your entry contains an attribute that is not
  #   allowed in this category.
  def add_entry(entry)
    entry.attributes.each_key do |attrname|
      raise(UnknownAttribute.new(self, entry, attrname)) unless @allowed_attributes.include?(attrname)
    end
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
    return if @allowed_attributes.include?(name)

    @allowed_attributes << name
    @entries.each do |entry|
      entry[name] = nil # Autoconverted to an empty string
    end
  end

  #Removes an attribute (plus value) from each entry
  #in this category.
  #If this attribute wasn’t existant before, does nothing.
  def delete_attribute(name)
    name = name.to_s
    return unless @allowed_attributes.include?(name)

    @allowed_attributes.delete(name)
    @entries.each do |entry|
      entry[name] = nil
    end
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

    categories_dir.join("#{self.class.generate_file_id}.xml").open("w") do |file|
      file.write(b.to_xml)
    end
  end

end
