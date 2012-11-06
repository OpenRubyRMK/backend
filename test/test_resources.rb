require_relative "helpers"

class ResourceTest < Test::Unit::TestCase
  include OpenRubyRMK::Backend
  include OpenRubyRMK::Backend::Fixtures
  include OpenRubyRMK::Backend::AdditionalAssertions

  def test_creation
    res = Resource.new(fixture("resources/ruby.png"))
    assert_equal(fixture("resources/ruby.png"), res.path)
    assert_equal(fixture("resources/ruby.png.yml"), res.info_file)
    assert_equal(2006, res.copyright.year)
    assert_equal("Yukihiro Matsumoto", res.copyright.author)
    assert_equal("CC-BY-SA 2.5", res.copyright.license)
    assert_equal("The Ruby Logo is", res.copyright.extra_info[0..15])

    assert_raises(OpenRubyRMK::Backend::Errors::NonexistantFile){Resource.new("nonexistant")} # entire file missing
    assert_raises(OpenRubyRMK::Backend::Errors::NonexistantFile){Resource.new("resources/foo.txt")} # .yml missing for this file
    assert_raises(OpenRubyRMK::Backend::Errors::NonexistantFile){Resource.new("resources/bar.txt")} # main resource file missing
  end

  def test_ice
    res = Resource.new(fixture("resources/ruby.png"))
    assert_frozen(res)
    assert_frozen(res.path)
    assert_frozen(res.info_file)
    assert_frozen(res.copyright)
    assert_raises(RuntimeError){res.copyright.author = "Me"}
  end

end
