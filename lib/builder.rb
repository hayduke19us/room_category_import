require_relative 'messages'

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
        sanitized_row = sanitize_row(row)

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
    include Messages
    attr_reader :brand_id, :room_code, :property_id, :supplier_code, :subsupplier_code

    def initialize(args)
      @brand_id         = args[:brand_id]
      @property_id      = args[:property_id]
      @room_code        = args[:room_type_id]
      @supplier_code    = args[:supplier_code]
      @subsupplier_code = args[:subsupplier_code]
    end

    def property_code_formats
      [
        [brand_id, property_id].join,
        [brand_id, property_id].join('-'),
        property_id
      ]
    end

    def supplier_property
      @supplier_property ||=
        ::SupplierProperty.where(
          :supplier_code    => supplier_code,
          :subsupplier_code => subsupplier_code,
          :property_code.in => property_code_formats
      ).first
    rescue NameError => e
      failure_msg
      handle use_as_rails_runner_msg(e)
    end

    def property
      supplier_property.property
    end

    def room_type_uuid
      Adapter.for(supplier_code.to_sym).room_type_uuid(supplier_property.property_code, room_code)
    end
  end
end
