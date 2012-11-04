# -*- coding: utf-8 -*-

# Special mixin module intended to be +extend+ed into existing
# instances of Ruby’s Hash class. It gives those objects the
# ability to recursively convert all keys to symbols or
# vice-versa, which is especially useful for configuration file
# handling. All without having to monkeypatch Ruby’s Hash class.
#
# On the other hand, with Ruby 2.0 this could easily be made
# a refinement of Hash inside the OpenRubyRMK::Backend module...
module OpenRubyRMK::Backend::SymbolifyableKeys

  # When this module is extended into an object, it will
  # automatically be extended into all sub-objects of the
  # same type as the extended objects as well. In other words,
  # if you extend this into a hash, this module will also be
  # extended recursively into all its sub-hashes.
  def self.extended(obj)
    obj.each_value do |val|
      val.extend(self) if val.kind_of?(obj.class)
    end
  end

  # Recursively converts all keys in the hash into symbols.
  # This is destructive and modifies the caller.
  def symbolify_keys!
    hsh = self.class.new
    hsh.extend(OpenRubyRMK::Backend::SymbolifyableKeys)

    each_key do |key|
      raise(TypeError, "Not symbolifyable key: #{key}") unless key.respond_to?(:to_sym)

      value           = fetch(key)
      value.symbolify_keys! if value.kind_of?(self.class)

      hsh[key.to_sym] = value
    end

    replace(hsh)
  end

  # Creates a new hash from +self+ with all keys recursively
  # converted to symbols and returns the new hash.
  def symbolify_keys
    hsh = clone # #dup doesn’t copy extends
    hsh.symbolify_keys!
    hsh
  end

  # Recursively converts all keys in the hash into strings.
  # This is destructive and modifies the caller.
  def stringify_keys!
    hsh = self.class.new
    hsh.extend(OpenRubyRMK::Backend::SymbolifyableKeys)

    each_key do |key|
      raise(TypeError, "Not stringifyable key: #{key}") unless key.respond_to?(:to_str) or key.kind_of?(Symbol)

      value         = fetch(key)
      value.stringify_keys! if value.kind_of?(self.class)

      if key.kind_of?(Symbol)
        hsh[key.to_s] = value
      else
        hsh[key.to_str] = value
      end
    end

    replace(hsh)
  end

  # Creates a new hash from +self+ with all keys recursively
  # converted to strings and returns the new hash.
  def stringify_keys
    hsh = clone # #dup doesn’t copy extends
    hsh.stringify_keys!
    hsh
  end

end
