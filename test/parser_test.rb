require_relative 'test_helper'

class ParserTest < Tester
  def setup
    super

    @file = File.open("#{Dir.pwd}/test/fixtures/test_csv.csv", 'r')
    @parser = Parser::RoomCategoryImport.new argv: [@file]
  end

  def test_parser_has_files_and_rows
    assert_equal @parser.files, [@file]
    assert_equal @parser.rows, []
  end

  def test_parse_with_files_parses_the_csv_files_into_hashes
    ARGF.stub :read, @file.read do
      rows = [
        {
          :brand_id => "B1234",
          :property_id => "P1234",
          :supplier_code => "intuitive",
          :subsupplier_code => "miki",
          :room_type_id => "R1234"
        }
      ]

      assert_equal rows, @parser.parse
    end
  end

  def test_parse_with_files_notifies_user
    assert_output(/You are about to map 1 Files/) do
      ARGF.stub :read, @file.read do
        @parser.parse
      end
    end
  end
end
