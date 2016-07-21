require 'csv'

START = Time.now.to_f

def total_time
  Time.now.to_f - START
end

module ErrorHandler
  def handle(error)
    raise "\n\n#{error}\n\n"
  end
end

module ErrorMessages
  def missing_files_msg
    %(
      No file paths were given as an argument.
    )
  end

  def invalid_csv_headers_msg(valid_headers)
    %(
      The CSV file is missing the correct headers. Must be one of #{valid_headers}
    )
  end

  def supplier_property_not_found_msg(room_category)
    %(
      Supplier property not found
      - supplier: #{room_category.supplier_code}
      - property_code: #{room_category.property_id}
    )
  end

  def not_equal(type, mapping_attribute, category_attribute)
    %(
      #{type.capitalize} conflict
        - room type mapping: #{mapping_attribute}
        - room category: #{category_attribute}
    )
  end

  def room_category_has_en_name_translation_msg
    %(
      Room category already has an english translation
    )
  end
end

module SuccessMessages
  def mapping_files_msg(files)
    %(
       You are about to map #{files.count} Files
       Files: #{files.join(", ")}
     )
  end

  def profile_msg
    %(
       Finished in #{total_time} seconds.
     )
  end
end


module Messages
  include ErrorHandler
  include ErrorMessages
  include SuccessMessages

  def say(msg)
    puts space msg
  end

  def space(msg)
    "\n\n#{msg}\n\n"
  end

  def counter_msg
    print '.'
  end

  def failure_msg
    print "F\n\n"
  end
end


module Parser
  class RoomCategoryImport
    include Messages

    attr_reader :files, :rows

    def initialize(args)
      @files = args.fetch(:argv, []).dup
      @rows  = []
    end

    def parse
      if files.empty?
        say missing_files_msg
      else
        say mapping_files_msg files
      end

      while files.any?
        counter_msg

        ARGV.replace [files.shift]
        rows.push CSV.new(ARGF.read, headers: true, header_converters: :symbol, converters: :all).to_a.map(&:to_hash)
      end

      rows
    end
  end
end

module Builder
  class RoomCategories
    include Messages
    attr_reader :rows
    attr_accessor :category, :mapping

    def initialize(args)
      @rows = args.fetch(:rows, [])
    end

    def rows_to_templates
      rows.map do |row|
        sanitized_row = sanitize_row(row.first)

        if sanitized_row.any?
          RoomCategoryTemplate.new(sanitized_row)
        else
          failure_msg
          say profile_msg

          handle invalid_csv_headers_msg(sanitized_keys.join(', '))
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
      rows_to_templates.each do |template|
        if template.supplier_property.present?
          build_room_category template
          build_room_type_mapping template
        else
          handle supplier_property_not_found_msg template
        end

        category.save!
      end

      say profile_msg
    end

    def build_room_category(template)
      self.category = template.property.room_categories.find_or_initalize_by id: template.room_code

      if category.en_name_text
        say room_category_has_en_translation_msg
      else
        category.name.build({ language: 'en', text: template.name }, UserTranslatedText)
      end
    end

    def build_room_type_mapping(template)
      self.mapping = room_category.room_type_mappings.find_or_initialize_by(
        room_type_id: room_category.room_type_uuid,
        supplier_property_id: room_category.supplier_property.id
      )

      if not_equal? mapping.room_type_id, template.room_type_uuid
        handle not_equal_msg 'room_type_id', mapping.room_type_id, category_template.room_type_uuid
      end

      if not_equal? mapping_template.room_type_code, template.room_code
        handle not_equal_msg 'room_type_code', mapping.room_type_code, template.room_code
      end

      mapping.supplier_property = template.supplier_property
      mapping.room_type_code    = template.room_code
      mapping.room_type_id      = template.room_type_uuid
    end

    def not_equal?(c1, c2)
      c1.presence && c1 != c2
    end
  end

  class RoomCategoryTemplate
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

