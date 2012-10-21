require "fileutils"
require "pathname"
require "yaml"
require "nokogiri"
require "tiled_tmx"

module OpenRubyRMK
  module Backend

    # The version of this software.
    VERSION = "0.0.1-dev"

    # Root directory of the backend library.
    ROOT_DIR = Pathname.new(__FILE__).dirname.parent.parent
    # data/ directory under ROOT_DIR.
    DATA_DIR = ROOT_DIR + "data"

  end
end

require_relative "backend/invalidatable"
require_relative "backend/map_storage"
require_relative "backend/project"
require_relative "backend/map"
