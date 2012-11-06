require_relative "helpers"

class HashTest < Test::Unit::TestCase

  def test_recursively_symbolize_keys
    obj = Object.new
    hsh = {"foo" => {"bar" => "baz", "blu" => 3}, :ff => "go", "fuu" => obj}
    assert_equal({:foo => {:bar => "baz", :blu => 3}, :ff => "go", :fuu => obj}, hsh.recursively_symbolize_keys)
    assert_equal(obj.object_id, hsh.recursively_symbolize_keys[:fuu].object_id) # no deep copy!

    hsh.recursively_symbolize_keys!
    assert_equal({:foo => {:bar => "baz", :blu => 3}, :ff => "go", :fuu => obj}, hsh)
    assert_equal(obj.object_id, hsh[:fuu].object_id)
  end

  def test_recursively_stringify_keys
    obj = Object.new
    hsh = {:foo => {:bar => :baz, :blu => 3}, "ff" => "go", :fuu => obj}
    assert_equal({"foo" => {"bar" => :baz, "blu" => 3}, "ff" => "go", "fuu" =>obj}, hsh.recursively_stringify_keys)
    assert_equal(obj.object_id, hsh.recursively_stringify_keys["fuu"].object_id) # no deep copy!

    hsh.recursively_stringify_keys!
    assert_equal({"foo" => {"bar" => :baz, "blu" => 3}, "ff" => "go", "fuu" =>obj}, hsh)
    assert_equal(obj.object_id, hsh["fuu"].object_id)
  end

end
