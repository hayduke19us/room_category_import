require 'csv'
require_relative 'builder'
require_relative 'parser'

module Import
  def self.now
    Builder::RoomCategories.new(rows: Parser::RoomCategoryImport.new(argv: ARGV).parse).build
  end
end
