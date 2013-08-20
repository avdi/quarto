module Quarto
  Font = Struct.new(:family, :weight, :style, :file) do
    def initialize(family, options={})
      self.family = family
      self.weight = options.delete(:weight) { "normal" }
      self.style  = options.delete(:style)  { "normal" }
      self.file   = options.delete(:file)   { nil }
      raise "Unknown options: #{options.inspect}" unless options.empty?
    end

    def to_font_face_rule
      <<END
@font-face {
  font-family: '#{family}';
  font-weight: #{weight};
  font-style:  #{style};
  src:         url(#{local_url}) format('#{format}');
}
END
    end

    def local_url
      Pathname(file).basename.to_s
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
  end
end
