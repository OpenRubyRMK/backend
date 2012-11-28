# -*- coding: utf-8 -*-

# A Resource represents a single external file of a project,
# e.g. a graphic or a background music file. It encapsulates
# information about the location, the type and the copyright
# conditions of this resource so you should find everything
# you need to properly display a resource in your GUI. A
# project’s list of resources can be retrieved via Project#resources,
# which will give you a (frozen) array of instances of this
# class. Also note that modifying these objects is meaningless
# (they only represent static information), hence they are
# frozen by default.
#
# Each resource always refers to an existing file on the
# filesystem (or at least it should), as well as a
# <i>resource information file</i> that contains the
# copyright information for that resoure. The latter is
# a simple YAML file whose structure is exaplained in
# the resource_info_files.rdoc document; it will automatically
# be loaded when you call the ::new method of this class.
class OpenRubyRMK::Backend::Resource

  # Files with one of these extensions are considered
  # to be graphical resources.
  GRAPHIC_RESOURCE_EXTS = %w[.png .jpg .jpeg .bmp .svg]

  # Files with one of these extensions are considered
  # to be audible resources.
  AUDIO_RESOURCE_EXTS = %w[.ogg .mp3 .midi]

  # Files with one of these extensions are considered
  # to be viewable resources.
  VIDEO_RESOURCE_EXTS = %w[.ogv .mp4]

  # Struct containing the copyright information of this
  # resource.
  CopyrightInfo = Struct.new(:year, :author, :license, :extra_info)

  # Full absolute path to this resource.
  attr_reader :path

  # Full absolute path to the resource’s copyright information file.
  attr_reader :info_file

  # The copyright information of this resource. A CopyrightInfo
  # struct.
  attr_reader :copyright

  # "Creates" a new Resource from the file at the given path.
  # == Parameter
  # [path]
  #   The path to the resource. The path to the copyright file
  #   is automatically derived from this by appending ".yml".
  # == Return value
  # A new instance of this class.
  def initialize(path)
    @path      = Pathname.new(path).expand_path
    @info_file = Pathname.new("#@path.yml")
    raise(OpenRubyRMK::Backend::Errors::NonexistantFile.new(@path)) unless @path.file?
    raise(OpenRubyRMK::Backend::Errors::NonexistantFile.new(@info_file)) unless @info_file.file?

    info = YAML.load_file(@info_file.to_s)
    @copyright = CopyrightInfo.new(info["year"],
                                   info["author"],
                                   info["license"],
                                   info["extra"])

    # This is a purely informational object.
    freeze
  end

  # Freezes this object, making it entirely resistant
  # against modifications. Called by default in ::new.
  def freeze
    @path.freeze
    @info_file.freeze
    @copyright.freeze
    super
  end

  # Human-readable description.
  def inspect
    "#<#{self.class} #{@path.basename} (Copyright (C) #{@copyright.year} #{@copyright.author})>"
  end

  # Checks if this resource actually refers to something on
  # the filesystem. For a resource to be considered valid,
  # both the path to the main resource file and the resource
  # information file must exist as valid files.
  def valid?
    @path.file? && @info_file.file?
  end

  # True if this is considered a graphical resource.
  def graphic?
    GRAPHIC_RESOURCE_EXTS.include?(@path.extname)
  end

  # True if this is considered an audible resource.
  def audio?
    AUDIO_RESOURCE_EXTS.include?(@path.extname)
  end

  # True if this is considered a viewable resource.
  def video?
    VIDEO_RESOURCE_EXTS.include?(@path.extname)
  end

  # True if this resource is not considered to be
  # a graphical, audible, or viewable resource.
  def other?
    !graphic? && !audio? && !video?
  end

end
