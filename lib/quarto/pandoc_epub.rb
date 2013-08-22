require "quarto/plugin"
require "nokogiri"
require "delegate"
require "quarto/path_helpers"

module Quarto
  class PandocEpub < Plugin
    include PathHelpers
    module BuildExt
      extend Forwardable

      attr_accessor :pandoc_epub
    end

    fattr(:target) { :epub3 }
    fattr(:flags) { %W[-w #{target_format} --epub-chapter-level 2 --no-highlight --toc] }
    fattr(:xml_write_options) {
      Nokogiri::XML::Node::SaveOptions::DEFAULT_XML |
      Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
    }

    def initialize(*)
      super
      unless valid_targets.include?(target)
        raise "target must be one of: #{valid_targets.join(', ')}"
      end
    end

    def enhance_build(build)
      build.extend(BuildExt)
      build.pandoc_epub = self
      build.deliverable_files << epub_file
    end

    def define_tasks
      desc "Build an epub file with pandoc"
      task :epub => "pandoc_epub:epub"

      namespace :pandoc_epub do
        task :epub => epub_file
      end

      file epub_file => [exploded_epub] do |t|
        replace_listings(exploded_epub, main.highlights_dir)
        fix_font_mimetypes("#{exploded_epub}/content.opf")
        add_fallback_styling_classes(exploded_epub)
        target = Pathname(t.name).relative_path_from(Pathname(exploded_epub))
        cd exploded_epub do
          files = FileList["**/*"]
          # mimetype file MUST be the first one into the zip file, so
          # we handle it separately.
          files.exclude("mimetype")
          # -X: no extended attributes. These make the EPUB invalid.
          sh "zip -X -r #{target} mimetype #{files}"
        end
      end

      directory exploded_epub => pristine_epub do |t|
        rm_rf exploded_epub if File.exist?(exploded_epub)
        mkdir_p exploded_epub
        sh *%W[unzip #{pristine_epub} -d #{exploded_epub}]
      end

      file pristine_epub => [
        *main.all_master_files,
        main.deliverable_dir,
        main.bitmap_cover_image,
        stylesheet,
        metadata_file,
        *font_files
      ] do |t|
        create_epub_file(
          t.name,
          main.master_file,
          stylesheet: stylesheet,
          metadata_file: metadata_file,
          font_files: font_files,
          cover_image: main.bitmap_cover_image)
      end

      file stylesheet => [pandoc_epub_dir, *stylesheets] do |t|
        sh "cat #{stylesheets} > #{t.name}"
      end

      file fonts_stylesheet do |t|
        create_fonts_stylesheet(t.name, fonts)
      end

      # In order to set stuff like author, title, etc. Pandoc requires
      # a metadata file containing XML Dublin Core properties. Note
      # that it doesn't care about proper namespacing.
      file metadata_file => main.master_file do |t|
        master_doc = open(main.master_file) do |f|
          Nokogiri::XML(f)
        end
        open(t.name, 'w') do |f|
          master_doc.css("meta").each do |meta|
            if meta["name"] =~ /^DC\.(.*)$/ && meta["content"].size > 0
              f.puts "<dc:#{$1}>#{meta["content"]}</dc:#{$1}>"
            end
          end
        end
      end

      rule %r(^#{pandoc_epub_dir}/fonts/.*\.woff$) => [->(f){source_font_for(f)}] do |t|
        mkdir_p t.name.pathmap("%d") unless File.exist?(t.name.pathmap("%d"))
        convert_font(t.source, t.name)
      end

      directory pandoc_epub_dir
    end

    private

    def create_epub_file(epub_file, master_file, options={})
      metadata_file = options.fetch(:metadata_file) { self.metadata_file }
      font_files    = options.fetch(:font_files)    { [] }
      pandoc_flags  = flags.dup
      master_dir    = master_file.pathmap("%d")
      epub_file     = rel_path(epub_file, master_dir)
      metadata_path = rel_path(metadata_file, master_dir)
      if stylesheet_file = options[:stylesheet]
        stylesheet_file = rel_path(stylesheet_file, master_dir)
        pandoc_flags.concat(%W[--epub-stylesheet #{stylesheet_file}])
      end
      if cover_image = options[:cover_image]
        pandoc_flags.concat(
          %W[--epub-cover-image #{rel_path(cover_image, master_dir)}])
      end
      font_files.each do |font_file|
        font_path = rel_path(font_file, master_dir)
        pandoc_flags.concat(%W[--epub-embed-font #{font_path}])
      end
      pandoc_flags.concat(%W[--epub-metadata #{metadata_path}])
      cd master_dir do
        sh pandoc, "-o", epub_file, master_file.pathmap("%f"), *pandoc_flags
      end
    end

    # Pandoc eats all tags inside <pre> tags, leaving only the
    # text. (See https://github.com/jgm/pandoc/issues/221). We have to
    # look up the highlighted listing by SHA1 and replace the
    # Pandoc-mangled listing with the original.
    def replace_listings(epub_dir, highlights_dir)
      files = FileList["#{epub_dir}/**/*.xhtml"]
      files.each do |file|
        doc = open(file) { |f|
          Nokogiri::XML(f)
        }
        listing_elts = doc.css("pre > code")
        if listing_elts.empty?
          puts "no listings in #{file}"
          next
        else
          puts "replace listings in #{file}"
        end
        listing_elts.each_with_index do |listing_elt, index|
          listing_elt = listing_elt.parent
          code = listing_elt.text
          sha1s = [Digest::SHA1.hexdigest(code), Digest::SHA1.hexdigest(code + "\n")]
          highlight_file = sha1s.map { |sha1|
            "#{highlights_dir}/#{sha1}.html"
          }.detect { |hf|
            File.exist?(hf)
          }
          if highlight_file
            puts "  replace listing ##{index + 1} with #{highlight_file}"
            listing_elt.replace(File.read(highlight_file))
          else
            puts "  no highlight found for listing ##{index + 1}"
            puts "----"
            puts listing_elt.text
            puts "----"
          end
        end
        open(file, 'w') do |f|
          doc.write_xml_to(f, save_with: xml_write_options)
        end
      end
    end

    def add_fallback_styling_classes(epub_dir)
      files = FileList["#{epub_dir}/**/*.xhtml"]
      files.each do |file|
        doc = open(file) { |f|
          Nokogiri::XML(f)
        }
        query = (1..6).map{|n| "h#{n} + p"}.join(", ")
        doc.css(query).each do |elt|
          heading_name = elt.previous_element.name
          classes = %W[first-para first-para-after-#{heading_name}]
          elt["class"] = (elt["class"].to_s.split + classes).join(" ")
        end
        # Why doesn't pandoc add "type" attributes to stylesheet link
        # tags when generating EPUB3? Who the fuck knows.
        # TODO: Move this into its own method, it is unrelated
        doc.css("link[rel='stylesheet'][href$='.css']").each do |elt|
          elt["type"] = "text/css"
        end
        open(file, 'w') do |f|
          doc.write_xml_to(f, save_with: xml_write_options)
        end
      end
    end

    def create_fonts_stylesheet(file, fonts)
      puts "generate #{file}"
      open(file, 'w') do |f|
        fonts.each do |font|
          f.puts(font.to_font_face_rule(basename: true))
        end
      end
    end

    # Replace Pandoc mimetypes with the ones recognized by the IDPF.
    # TODO Maybe refactor this to use MIME::Types if it reurns
    #      IDPF-compliant types.
    def fix_font_mimetypes(package_file)
      doc = open(package_file) {|f|
        Nokogiri::XML(f)
      }
      doc.css("manifest item[media-type='application/x-font-woff']").each do |elt|
        elt["media-type"] = "application/font-woff"
      end
      doc.css("manifest item[media-type='application/x-font-opentype']").each do
        |elt|
        elt["media-type"] = "application/vnd.ms-opentype"
      end
      open(package_file, 'w') do |f|
        doc.write_xml_to(f)
      end
    end

    # The final product
    def epub_file
      "#{main.deliverable_dir}/#{main.name}.epub"
    end

    def stylesheet
      "#{pandoc_epub_dir}/stylesheet.css"
    end

    # The directory into which we unpack the pristine_epub so that we
    # can fix it up.
    def exploded_epub
      "#{pandoc_epub_dir}/book"
    end

    # The pristine EPUB file is the one that Pandoc produces, before
    # we unpack it and do various fix-ups to it.
    def pristine_epub
      "#{pandoc_epub_dir}/book.epub"
    end

    def pandoc_epub_dir
      "#{main.build_dir}/pandoc_epub"
    end

    def pandoc
      main.pandoc
    end

    def fonts_stylesheet
      "#{pandoc_epub_dir}/fonts.css"
    end

    def metadata_file
      "#{pandoc_epub_dir}/metadata.xml"
    end

    def stylesheets
      main.stylesheets.applicable_to(target).master_files + [fonts_stylesheet]
    end

    def valid_targets
      [:epub2, :epub3]
    end

    def target_format
      case target
      when :epub2 then "epub"
      when :epub3 then "epub3"
      else raise "Unknown target #{target}"
      end
    end

    # Return a list of font file paths where any non-EPUB3-standard
    # font extensions are replaced with ".woff". See also
    # #convert_font.
    def font_files
      orig_files = FileList[*main.fonts.map(&:file)]
      supported, unsupported = orig_files.partition{|f|
        %W[.otf .woff].include?(f.pathmap("%x"))
      }
      (supported + unsupported.pathmap("#{pandoc_epub_dir}/fonts/%n.woff"))
    end

    def source_font_for(target_font)
      orig_files = main.fonts.map(&:file)
      orig_files.detect{|f| f.pathmap("%n") == target_font.pathmap("%n")}
    end

    # While some (many?) readers support TrueType, SVG, etc. fonts,
    # EPUB3 only requires support for WOFF and OpenType. This method
    # uses FontForge (http://fontforge.org/) to convert from arbitrary
    # font types to WOFF.
    def convert_font(source_font, target_font)
      convert_script = File.expand_path("../../../fontforge/convert.pe", __FILE__)
      sh "fontforge", "-script", convert_script, source_font, target_font
    end

    def font_file_for_epub(orig_file)
      font_files.detect{|f| orig_file.pathmap("%n") == f.pathmap("%n")}
    end

    def fonts
      main.fonts.map{|font|
        if %W[.otf .woff].include?(font.file.pathmap("%x"))
          font
        else
          font = font.dup
          font.file = font_file_for_epub(font.file)
          font
        end
      }
    end

  end
end
