# -*- coding: utf-8 -*-
# This file contains monkeypatches to the Ruby core.
# It should be required prior to anything else in the
# ORR.

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

# Extensions to Ruby’s Integer class.
class Integer

  # Like Kernel#Integer, but also accepts "Infinity"
  # and "-Infinity" as valid values.
  def self.[](str)
    if str == "Infinity"
      Float::INFINITY
    elsif str == "-Infinity"
      -Float::INFINITY
    else
      Integer(str)
    end
  end

end

# Extensions to Ruby’s Float class.
class Float

  # Like Kernel#Float, but also accepts "Infinity" and
  # "-Infinity" as valid values.
  def self.[](str)
    if str == "Infinity"
      Float::INFINITY
    elsif str == "-Infinity"
      -Float::INFINITY
    else
      Float(str)
    end
  end

end
