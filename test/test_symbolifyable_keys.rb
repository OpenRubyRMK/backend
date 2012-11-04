require_relative "helpers"

class SymbolifyableKeysTest < Test::Unit::TestCase
  include OpenRubyRMK::Backend

  def setup
    @flat_hsh = {"foo" => "bar"}
    @nested_hsh = {"foo" => {"bar" => "baz"}, "blu" => 3}
    @flat_hsh_sym = {:foo => "bar"}
    @nested_hsh_sym = {:foo => {:bar => "baz"}, :blu => 3}

    # Note that we cannot #extend in the setup, because we
    # want to ensure that #assert_equal uses a non-extended
    # hash as the expectation value.
  end

  def test_symbolify_keys
    @flat_hsh.extend(SymbolifyableKeys)
    assert_equal(@flat_hsh_sym, @flat_hsh.symbolify_keys)

    @nested_hsh.extend(SymbolifyableKeys)
    assert_equal(@nested_hsh_sym, @nested_hsh.symbolify_keys)
  end

  def test_symbolify_keys!
    @flat_hsh.extend(SymbolifyableKeys)
    @flat_hsh.symbolify_keys!
    assert_equal(@flat_hsh_sym, @flat_hsh)

    @nested_hsh.extend(SymbolifyableKeys)
    @nested_hsh.symbolify_keys!
    assert_equal(@nested_hsh_sym, @nested_hsh)
  end

  def test_stringify_keys
    @flat_hsh_sym.extend(SymbolifyableKeys)
    assert_equal(@flat_hsh, @flat_hsh_sym.stringify_keys)

    @nested_hsh_sym.extend(SymbolifyableKeys)
    assert_equal(@nested_hsh, @nested_hsh_sym.stringify_keys)
  end

  def test_stringify_keys!
    @flat_hsh_sym.extend(SymbolifyableKeys)
    @flat_hsh_sym.stringify_keys!
    assert_equal(@flat_hsh, @flat_hsh_sym)

    @nested_hsh_sym.extend(SymbolifyableKeys)
    @nested_hsh_sym.stringify_keys!
    assert_equal(@nested_hsh, @nested_hsh_sym)
  end

  def test_invalid_hashes
    hsh = {[] => "foo"}
    hsh.extend(OpenRubyRMK::Backend::SymbolifyableKeys)

    assert_raises(TypeError){hsh.symbolify_keys!}
    assert_raises(TypeError){hsh.symbolify_keys}
    assert_raises(TypeError){hsh.stringify_keys!}
    assert_raises(TypeError){hsh.stringify_keys}
  end

end
