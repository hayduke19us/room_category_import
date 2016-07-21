require_relative 'test_helper'

class BuilderTest < Tester
  def setup
    super
    @file = File.open("#{Dir.pwd}/test/fixtures/test_csv.csv", 'r')

    ARGF.stub :read, @file.read do
      @rows = Parser::RoomCategoryImport.new(argv: [@file]).parse
    end

    @builder = Builder::RoomCategories.new rows: @rows
  end

  def test_the_builder_has_rows_as_an_array_of_hashes
    assert_equal @rows, @builder.rows
    assert @builder.rows.first.is_a? Hash
  end

  def test_rows_to_templates_maps_each_row_into_a_room_category_template
    templates = @builder.rows_to_templates
    assert templates.first.is_a? Builder::RoomCategoryTemplate
  end

  def test_invalid_csv_headers_raises_an_error
    @builder.stub :sanitize_row, [] do
      assert_raises { @builder.rows_to_templates }
    end
  end
end
