module GoldenChild
  BlockContentFilter = Struct.new(:patterns, :block) do
    # @return [true, false] whether any of the patterns match
    def ===(filename)
      patterns.any?{|pattern|
        case pattern
        when String
          File.fnmatch(pattern, filename.to_s)
        else
          pattern === filename.to_s
        end
      }
    end

    def call(file_content)
      block.call(file_content)
    end
  end
end
