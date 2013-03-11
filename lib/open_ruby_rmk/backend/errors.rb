# -*- coding: utf-8 -*-

# This module holds all custom exception classes that the
# OpenRubyRMK backend library uses.
module OpenRubyRMK::Backend::Errors

  # Base class for all exceptions in all OpenRubyRMK
  # libraries.
  class OpenRubyRMKError < StandardError
  end

  # Base class for all exceptions in this library.
  class OpenRubyRMKBackendError < OpenRubyRMKError
  end

  # Raised when something expected on the filesystem couldn’t
  # be found. Beware, this may also be raised if the target
  # path’s type is wrong (e.g. a directory instead of a file,
  # or a socket where a directory should be, etc.).
  class InvalidPath < OpenRubyRMKBackendError

    # The directory in question, as a Pathname instance.
    attr_reader :path

    # Creates a new exception of this type.
    def initialize(path, msg = nil)
      super(msg || "The path '#{path}' doesn't exist or isn't of the expected type.")
      @path = Pathname.new(path)
    end

  end

  # Raised when a directory couldn’t be found.
  class NonexistantDirectory < InvalidPath

    # Creates a new exception of this type.
    def initialize(path, msg = nil)
      super(path, msg || "Not a directory: '#{path}'.")
    end

  end

  # Raised when a file couldn’t be found.
  class NonexistantFile < InvalidPath

    def initialize(path, msg = nil)
      super(path, msg || "Not a file: '#{path}'.")
    end

  end

  # Something failed to parse.
  class ParseError < OpenRubyRMKBackendError

    # The path to the errorneous file. May be +nil+ if no file
    # is applicable.
    attr_reader :path
    # The faulty line, if applicable and determinable. +nil+ Otherwise.
    attr_reader :line

    # Creates a new exception of this type. The message is mandatory
    # and will be prefixed with "Parsing error: ".
    def initialize(path, line, message)
      super("Parsing error: #{message}")

      @path = path
      @line = line
    end

  end

  # Raised when multiple maps having the same ID are
  # detected.
  class DuplicateMapID < OpenRubyRMKBackendError

    # The duplicate map ID.
    attr_reader :map_id

    # Creates a new exception of this type.
    def initialize(map_id, msg = nil)
      super(msg || "Duplicate map ID #{map_id}!")
      @map_id = map_id
    end

  end

  # Raised when you try to define an attribute multiple times
  # on a category.
  class DuplicateAttribute < OpenRubyRMKBackendError

    # The name of the faulty attribute.
    attr_reader :name

    # Creates a new exception of this class.
    # == Parameters
    # [name]
    #   The name of the duplicate attribute.
    # [msg (nil)]
    #   A non-default error message.
    def initialize(name, msg = nil)
      super(msg || "The attribute `#{name}' already exists.")
      @name = name
    end

  end

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

  # Raised if an entry is somehow invalid.
  class InvalidEntry < OpenRubyRMKBackendError

    # The bad Category::Entry instance.
    attr_reader :entry

    # Create a new exception of this type, passing the entry in question
    # and the error message.
    def initialize(entry, message)
      @entry = entry
      super(message)
    end

  end

end
