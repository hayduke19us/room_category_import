module ErrorHandler
  def handle(error)
    raise "\n\n#{error}\n\n"
  end
end

module ErrorMessages
  def missing_files_msg
    %(
      No file paths were given as an argument.
      #{usage_msg}
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

  def not_equal_msg(type, mapping_attribute, category_attribute)
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

  def use_as_rails_runner_msg(exception)
    %(
      #{exception.inspect}
      - Use from within a rails application as:
      #{usage_msg}
    )
  end

  def usage_msg
    %(
      Rails Usage: rails r ./bin/import file1.csv file2.csv
      Ruby Usage: ./bin/import file1.csv file2.csv
    )
  end
end

module SuccessMessages
  START = Time.now.to_f

  def total_time
    Time.now.to_f - START
  end

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
