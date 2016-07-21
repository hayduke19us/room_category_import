require 'csv'
require_relative 'builder'
require_relative 'parser'

module Import
  def self.now
    unless ENV['test']
      builder = Builder::RoomCategories.new rows: Parser::RoomCategoryImport.new(argv: ARGV).parse
      builder.build
    end
  end
end
