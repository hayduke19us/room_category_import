require_relative 'test_helper'

class BuilderTest < Tester
  def setup
    super
    @file = File.open("#{Dir.pwd}/test/fixtures/test_csv.csv", 'r')

    ARGF.stub :read, @file.read do
      @rows = Parser::RoomCategoryImport.new(argv: [@file]).parse
    end

    @builder   = Builder::RoomCategories.new rows: @rows
    @template = @builder.rows_to_templates.first
  end

  def test_the_builder_has_rows_as_an_array_of_hashes
    assert_equal @rows, @builder.rows
    assert @builder.rows.first.is_a? Hash
  end

  def test_rows_to_templates_maps_each_row_into_a_room_category_template
    assert @template.is_a? Builder::RoomCategoryTemplate
  end

  def test_a_room_category_template_has_attributes_synonomous_with_the_row
    assert_equal 'B1234', @template.brand_id
    assert_equal 'R1234', @template.room_code
    assert_equal 'P1234', @template.property_id
    assert_equal 'intuitive', @template.supplier_code
    assert_equal 'miki', @template.subsupplier_code
  end

  def test_property_code_formats_returns_an_array_for_different_property_codes
    formats = ["B1234P1234", "B1234-P1234", "P1234"]

    assert_equal formats, @template.property_code_formats
  end

  def test_invalid_csv_headers_raises_an_error
    @builder.stub :sanitize_row, [] do
      assert_raises { @builder.rows_to_templates }
    end
  end

  def test_build_room_category_category_that_already_has_an_english_translation
    room_category = Struct.new(:en_name_text).new
    room_category.en_name_text = true

    @builder.stub :find_or_create_room_category, room_category, [@template] do
      assert_output(/Room category already has an english translation/) do
        @builder.build_room_category @template
      end
    end
  end

  def test_find_or_create_room_category_finds_or_initializes_by_id_with_room_code
    property        = MiniTest::Mock.new
    room_categories = MiniTest::Mock.new
    room_category   = MiniTest::Mock.new

    @template.stub :property, property do
      property.expect :room_categories, room_categories
      room_categories.expect :find_or_initialize_by, room_category, [{ id: @template.room_code }]

      @builder.find_or_create_room_category @template
    end
  end

  def test_not_equal_compares_two_arbitrary_objects
    assert @builder.not_equal?(1, 2)
    refute @builder.not_equal?(1, 1)
  end

  def test_build_room_type_mapping_raises_an_error_if_room_type_id_conflicts_exist
    mapping = Struct.new(:room_type_id).new
    mapping.room_type_id = true

    @builder.stub :find_or_create_room_type_mapping, mapping do
      @template.stub :room_type_uuid, false do
        assert_raises { @builder.build_room_type_mapping @template }
      end
    end
  end

  def test_build_room_type_mapping_raises_an_error_if_room_type_code_conflicts_exist
    mapping = Struct.new(:room_type_id, :room_type_code).new
    mapping.room_type_id   = true
    mapping.room_type_code = true

    @builder.stub :find_or_create_room_type_mapping, mapping do
      @template.stub :room_type_uuid, true do
        @template.stub :room_code, false do
          assert_raises { @builder.build_room_type_mapping @template }
        end
      end
    end
  end

  def test_build_room_type_mapping_sets_mapping_attributes
    mapping = Struct.new(:room_type_id, :room_type_code, :supplier_property).new
    mapping.room_type_id   = true
    mapping.room_type_code = true

    @builder.stub :find_or_create_room_type_mapping, mapping do
      @template.stub :room_type_uuid, true do
        @template.stub :room_code, true do
          @template.stub :supplier_property, true do
            @builder.build_room_type_mapping @template
            assert mapping.supplier_property
            assert mapping.room_type_code
            assert mapping.room_type_id
          end
        end
      end
    end
  end
end
