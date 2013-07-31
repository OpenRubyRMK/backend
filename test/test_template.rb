# -*- coding: utf-8 -*-
require_relative "helpers"

class TemplateTest < Test::Unit::TestCase
  include OpenRubyRMK
  include OpenRubyRMK::Backend
  include OpenRubyRMK::Backend::AdditionalAssertions

  def setup
    $items = []

    @template = Template.new "chest" do
      page do
        graphic "page1.png"
        parameter :item, :type => :string
        parameter :count, :type => :number, :default => 1

        code <<-CODE
          %{count}.times do
            $items << "%{item}"
          end
        CODE
      end
      page do
        parameter :text, :type => :string

        code <<-CODE
          $items << "%{text}"
        CODE
      end
    end
  end

  def test_template_properties
    assert_equal "chest", @template.name
    assert_equal Map::DEFAULT_TILE_EDGE, @template.width
    assert_equal Map::DEFAULT_TILE_EDGE, @template.height
    assert_equal 2, @template.pages.count

    page = @template.pages.first
    assert page
    assert_equal 0, page.number
    assert_equal "page1.png", page.graphic
    assert_equal 2, page.parameters.count
    assert_equal "item", page.parameters.first.name
    assert_equal :string, page.parameters.first.type
    assert_equal nil, page.parameters.first.default_value

    page = @template.pages.last
    assert page
    assert_equal 1, page.number
    assert_equal nil, page.graphic
    assert_equal "text", page.parameters.first.name
    assert_equal :string, page.parameters.first.type
  end

  def test_template_evaluation
    assert_empty $items

    @template.result([{:count => 3, :item => "foo"}, {:text => "This is the text."}]) do |page, result|
      eval(result)
    end

    assert_equal ["foo", "foo", "foo", "This is the text."], $items
  end

  def test_from_and_to_xml
    Dir.mktmpdir do |tmpdir|
      path = @template.save(tmpdir)

      # Read it back in
      template = Template.from_file(path)
      assert_equal @template, template

      assert_equal "chest", template.name
      assert_equal 2, template.pages.count

      assert_equal "page1.png", template.pages.first.graphic
      refute_empty template.pages.first.code

      assert_equal "item", template.pages.first.parameters.first.name
      assert_equal :string, template.pages.first.parameters.first.type
      assert template.pages.first.parameters.first.required?

      assert_equal "count", template.pages.first.parameters.last.name
      assert_equal :number, template.pages.first.parameters.last.type
      refute template.pages.first.parameters.last.required?
      assert_equal 1, template.pages.first.parameters.last.default_value

      assert_equal nil, template.pages.last.graphic
      refute_empty template.pages.last.code
    end
  end

end