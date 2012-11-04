# -*- coding: utf-8 -*-
require "fileutils"
require "observer"
require "set"
require "pathname"
require "yaml"
require "nokogiri"
require "tiled_tmx"

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
require_relative "backend/symbolifyable_keys"
