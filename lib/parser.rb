require_relative 'messages'

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

      rows.flatten
    end
  end
end
