# -*- coding: utf-8 -*-
require "fileutils"
require "observer"
require "set"
require "pathname"
require "yaml"
require "nokogiri"
require "tiled_tmx"

# Extensions to Ruby’s Hash class.
class Hash

  # Creates a new hash where recursively all Symbol keys have
  # been converted to Strings. Note that non-hash values are
  # *not* copied over, but only references (i.e. no deep copy
  # is done for them).
  def recursively_symbolize_keys
    hsh = {}
    each_pair do |k, v|
      k = k.to_sym if k.kind_of?(String)
      v = v.recursively_symbolize_keys if v.kind_of?(self.class)
      hsh[k] = v
    end

    hsh
  end

  # Creates a new hash where recursively all String keys have
  # been converted to strings. Note that non-hash values are
  # *not* copied over, but only references (i.e. no deep copy
  # is done for them).
  def recursively_stringify_keys
    hsh = {}
    each_pair do |k, v|
      k = k.to_s if k.kind_of?(Symbol)
      v = v.recursively_stringify_keys if v.kind_of?(self.class)
      hsh[k] = v
    end

    hsh
  end

  # *Recursively* turns all the hash’s String keys into
  # symbols.
  def recursively_symbolize_keys!
    keys.each do |k|
      next unless k.kind_of?(String)
      v = fetch(k)

      # If we have a sub hash here, symbolize it
      v.recursively_symbolize_keys! if v.kind_of?(self.class)
      # Refcopy the value
      store(k.to_sym, v)
      # Remove the old value
      delete(k)
    end
  end

  # *Recursively* turns all the hash’s Symbol keys into
  # strings.
  def recursively_stringify_keys!
    keys.each do |k|
      next unless k.is_a?(Symbol)
      v = fetch(k)

      # If we have a sub hash here, stringify it
      v.recursively_stringify_keys! if v.kind_of?(self.class)
      # Refcopy the value
      store(k.to_s, v)
      # Remove the old value
      delete(k)
    end
  end

end

# Namespace for the OpenRubyRMK project.
module OpenRubyRMK

  # Namespace for the OpenRubyRMK’s backend library, i.e.
  # the library containing the facilities to actually
  # manipulate projects and their components. All GUIs
  # build upon this.
  module Backend

    # Root directory of the backend library.
    ROOT_DIR = Pathname.new(__FILE__).dirname.parent.parent
    # data/ directory under ROOT_DIR.
    DATA_DIR = ROOT_DIR + "data"
    # Path to the VERSION file.
    VERSION_FILE = ROOT_DIR + "VERSION"

    # The version of this software.
    def self.version
      VERSION_FILE.read.chomp
    end

  end
end

require_relative "backend/errors"
require_relative "backend/eventable"
require_relative "backend/invalidatable"
require_relative "backend/map_storage"
require_relative "backend/project"
require_relative "backend/map"
require_relative "backend/category"
