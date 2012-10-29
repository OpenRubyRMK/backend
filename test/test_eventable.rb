require_relative "helpers"

class EventableTest < Test::Unit::TestCase
  include OpenRubyRMK::Backend

  # This is the class whose instance we want to observe.
  class ObservedThing
    include OpenRubyRMK::Backend::Eventable

    # Initialise it with a default value.
    def initialize
      @value = 0
    end

    # Change the value, and notify all observers.
    def change_the_state!
      changed
      @value = rand(100)
      notify_observers(:state_changed, @value)
    end

    # Change the value with another event, and notify
    # all observers.
    def change_the_state_differently!
      changed
      @value = 0 - rand(100)
      notify_observers(:state_changed_differently, @value)
    end

  end

  # A sample observer for ObservedThing.
  class AnObserver

    attr_reader :results

    # Initialise it with an empty results array.
    def initialize
      @results = []
    end

    # Callback called by ObservedThing.
    def update(event, value)
      @results << event
    end

  end

  def test_observe_blocks
    # Without a filter
    target = ObservedThing.new
    results = []
    target.observe{|event, value| results << event}
    target.change_the_state!
    target.change_the_state_differently!
    target.change_the_state!
    assert_equal([:state_changed, :state_changed_differently, :state_changed], results)

    # With filter
    target = ObservedThing.new
    results = []
    target.observe(:state_changed){|event, value| results << event}
    target.change_the_state!
    target.change_the_state_differently!
    target.change_the_state!
    assert_equal([:state_changed, :state_changed], results)

    # Different filter
    target = ObservedThing.new
    results = []
    target.observe(:state_changed_differently){|event, value| results << event}
    target.change_the_state!
    target.change_the_state_differently!
    target.change_the_state!
    assert_equal([:state_changed_differently], results)
  end

  def test_observe_classes
    target = ObservedThing.new
    observer = AnObserver.new
    target.add_observer(observer)
    target.change_the_state!
    target.change_the_state_differently!
    target.change_the_state!
    assert_equal([:state_changed, :state_changed_differently, :state_changed], observer.results)
  end

end
