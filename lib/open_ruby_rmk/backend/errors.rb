# -*- coding: utf-8 -*-

# This module holds all custom exception classes that the
# OpenRubyRMK backend library uses.
module OpenRubyRMK::Backend::Errors

  # Base class for all exceptions in this library.
  class OpenRubyRMKBackendError < StandardError
  end

  # Raised when a directory couldn’t be found.
  class NonexistantDirectory < OpenRubyRMKBackendError

    # The directory in question, as a Pathname instance.
    attr_reader :path

    # Creates a new exception of this type.
    def initialize(path, msg = nil)
      super(msg || "The directory '#{path}' couldn’t be found.")
      @path = Pathname.new(path)
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

end
