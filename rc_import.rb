#!/usr/bin/env script/rails runner

require 'optparse'
require 'csv'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby rc_import.rb [options] 'file_path' file_path' 'file_path'"

  opts.on("-v", "--verbose", "Run verbosely") do
    options[:verbose] = true
  end
end.parse!

VERBOSE = options[:verbose]
START   = Time.now.to_f

def counter_msg
  print '.'
end

def failure_msg
  print "F\n\n"
end


def total_time
  Time.now.to_f - START
end

def profile_msg
  %(
     Finished in #{total_time} seconds.
   )
end

module Parser
  class RoomCategoryImport
    attr_reader :files, :rows

    def initialize(args)
      @files = args.fetch(:argv, []).dup
      @rows  = []
    end

    def parse
      puts verbose_msg_missing_files if VERBOSE && files.empty?
      puts verbose_msg_files if VERBOSE && files.any?
      while files.any?
        counter_msg  if VERBOSE

        ARGV.replace [files.shift]
        rows.push CSV.new(ARGF.read, headers: true, header_converters: :symbol, converters: :all).to_a.map(&:to_hash)
      end

      rows
    end

    def verbose_msg_files
      %(
         You are about to map #{files.count} Files
         Files: #{files.join(", ")}
       )
    end

    def verbose_msg_missing_files
      %(
         No file paths were given as an argument.
         Type `ruby rc_import.rb -h` for Help.
       )
    end
  end
end

module Builder
  class RoomCategories
    attr_reader :rows

    def initialize(args)
      @rows = args.fetch(:rows, [])
    end

    def to_room_categories
      rows.map do |row|
        sanitized_row = sanitize_row(row.first)

        if sanitized_row.any?
          RoomCategory.new(sanitized_row)
        else
          failure_msg if VERBOSE
          puts profile_msg if VERBOSE
          raise "\n\nThe CSV file is missing the correct headers. Must be one of #{sanitized_keys.join(", ")}\n\n"
        end
      end
    end

    def sanitize_row(row)
      row.select { |key, _| sanitized_keys.include?(key) }
    end

    def sanitized_keys
      [:brand_id, :room_type_id, :property_id, :supplier_code, :subsupplier_code]
    end

    def build
      to_room_categories.each do |room_category|
        unless room_category.supplier_property.present?
          raise "\nSupplier property not found supplier: #{room_category.supplier_code}" \
                "property_code: #{room_category.property_id}"
        end

        rc = room_category.property.room_categories.find_or_initalize_by id: room_category.room_code

        rc_mapping = rc.room_type_mappings.find_or_initialize_by(
          room_type_id: room_category.room_type_uuid ,
          supplier_property_id: room_category.supplier_property.id
        )

        unless room_type_id_set? rc_mapping, rc.room_type_uuid
          raise conflict_error_msg 'room_type_id', rc_mapping, rc.room_type_uuid
        end

        unless room_code_conflict? rc_mapping, rc.room_code
          raise conflict_error_msg 'room_type_code', rc_mapping, rc.room_type_uuid
        end

        rc_mapping.supplier_property = rc.supplier_property
        rc_mapping.room_type_code    = rc.room_type_code
        rc_mapping.room_type_id      = rc.room_type_id

        rc.name.build({ language: 'en', text: rc.name }, UserTranslatedText)
        rc.save!
      end

      puts profile_msg if VERBOSE
    end

    def room_type_id_set?(mapping, uuid)
      mapping.room_type_id.presence && mapping.room_type_id != uuid
    end

    def conflict_error_msg(type, mapping, rc)
      "\nFound room #{type} that differs - mapping: #{mapping.room_type_code} / category: #{rc.room_code}\n"
    end

  end

  class RoomCategory
    attr_reader :brand_id, :room_code, :property_id, :supplier_code, :subsupplier_code

    def initialize(args)
      @brand_id         = args[:brand_id]
      @property_id      = args[:property_id]
      @supplier_code    = args[:supplier_code]
      @subsupplier_code = args[:subsupplier_code]
    end

    def property_code_formats
      [
        [brand_id, property_id.to_s.rjust(5, '0')].join,
        [brand_id, property_id.to_s.rjust(5, '0')].join('-'),
        [brand_id, property_id.to_s].join('-'),
      ]
    end

    def supplier_property
      @supplier_property ||=
        ::SupplierProperty.where(
          :supplier_code    => supplier_code,
          :subsupplier_code => subsupplier_code,
          :property_code.in => property_code_formats
      ).first
    end

    def property
      supplier_property.property
    end

    def room_type_uuid
      Adapter.for(supplier_code.to_sym).room_type_uuid(supplier_property.property_code, room_code)
    end
  end
end


builder = Builder::RoomCategories.new rows: Parser::RoomCategoryImport.new(argv: ARGV).parse
builder.build

