require "quarto/uri_helpers"

module Quarto
  Font = Struct.new(:family, :weight, :style, :file) do
    include UriHelpers

    def initialize(family, options={})
      self.family = family
      self.weight = options.delete(:weight) { "normal" }
      self.style  = options.delete(:style)  { "normal" }
      self.file   = options.delete(:file)   { nil }
      raise "Unknown options: #{options.inspect}" unless options.empty?
    end

    def to_font_face_rule(options={})
      <<END
@font-face {
  font-family: '#{family}';
  font-weight: #{weight};
  font-style:  #{style};
  src:         url(#{local_url(options)}) format('#{format}');
}
END
    end

    def local_url(options={})
      embed    = options[:embed]
      basename = options[:basename]

      if embed
        "'#{data_uri}'"
      else
        if basename
          Pathname(file).basename.to_s
        else
          file
        end
      end
    end

    def format
      case ext = Pathname(file).extname[1..-1]
      when "ttf" then "truetype"
      when "otf" then "opentype"
      when "woff" then "woff"
      when "svg" then "svg"
      else ext
      end
    end

    def type
      case ext = Pathname(file).extname[1..-1]
      when "ttf" then "application/x-font-ttf"
      when "otf" then "application/vnd.ms-opentype"
      when "woff" then "application/font-woff"
      when "svg" then "image/svg+xml"
      else raise "Unknown font type #{ext}"
      end
    end

    def data_uri
      data_uri_for_file(file, type)
    end
  end
end
