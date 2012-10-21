# -*- coding: utf-8 -*-

#Mixin module allowing objects to (mostly) commit
#suicide by unsetting all instance variables of
#the object in question.
module OpenRubyRMK::Backend::Invalidatable

  #Sets all the object’s instance variables to +nil+.
  #Using this objects afterwards will most likely cause
  #an exception, which is the sole purpose of this method.
  def invalidate!
    instance_variables.each do |ivar|
      instance_variable_set(ivar, nil)
    end

    nil
  end

end
