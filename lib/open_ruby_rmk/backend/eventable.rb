# -*- coding: utf-8 -*-

# Extension module for Ruby’s Observable module. The basic
# idea is still to notify other objects when an observed
# object changes, but this module adds a few restrictions
# to the very free form Observable exposes:
#
# * The first argument to +notify_observers+ is an event name
#   (a symbol).
# * Observers can register either via the regular class-based
#   mechanism used by Observable, or by a nice block-based
#   interface provided by the #observe method. This method
#   also lets you filter by event type.
#
# As already indicated, these restrictions make it easier
# to process the information emitted by the observable
# object, merely by defining a format for this information.
# Using #observe, you can filter which events you want to
# listen to, instead of having to put a long +case+ statement
# or similar in your +update+ method (which you still can do,
# if you prefer or if it better fits your situation).
#
# == Example
#
#   class Car
#     include Eventable
#
#     attr_reader :velocity
#
#     def initialize
#       @velocity = 0
#       @working = true
#     end
#
#     def accelerate(delta)
#       changed
#       @velocity += delta
#       notify_observers :velocity_changed, :new_velocity => @velocity
#     end
#
#     def explode!
#       changed
#       puts "BOOOOM"
#       @velocity = 0
#       @working = false
#       notify_observers :velocity_changed, :new_velocity => 0
#       notify_observers :exploded
#     end
#
#   end
#
#   car = Car.new
#   car.observe(:velocity_changed){|event, sender, info| puts "New velocity: #{info[:new_velocity]}"}
#   car.accelerate(10) #=> New velocity: 10
#   car.accelerate(20) #=> New velocity: 30
#   car.explode!       #=> New velocity: 0
#
# NOTE: This module may be extended later.
module OpenRubyRMK::Backend::Eventable
  include Observable

  # Alternative method to register an observer. In
  # contrast to Observable#add_observer, which requires
  # you to construct an object responding to :update or
  # specify another symbol, this method takes a block
  # that will be called when the observed object emmits
  # an event of the requested type.
  # == Parameters
  # [target_event (nil)]
  #   Only fire the callback if the observed object issued
  #   an event of this type. If this is +nil+, the callback
  #   is always fired when the observed object changes.
  def observe(target_event = nil)
    callback = lambda do |event, emitter, info|
      yield(event, emitter, info) if !target_event || event == target_event
    end

    add_observer(callback, :call)
  end

  # Works the same way as Observable#notify_observers, but
  # automatically inserts +self+ as the second argument to
  # the +super+ call so that observers know who called.
  # +info+ is a hash that will be passed through to the observers.
  def notify_observers(event, info = {})
    super(event, self, info)
  end

end
