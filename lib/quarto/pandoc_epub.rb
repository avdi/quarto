require "quarto/plugin"
require "nokogiri"
require "delegate"

module Quarto
  class PandocEpub < Plugin
    module BuildExt
      extend Forwardable

      attr_accessor :pandoc_epub
    end

    fattr(:flags) { %W[-w epub3 --epub-chapter-level 2 --no-highlight --toc] }
    fattr(:xml_write_options) {
      Nokogiri::XML::Node::SaveOptions::DEFAULT_XML |
      Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
    }

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
        target = Pathname(t.name).relative_path_from(Pathname(exploded_epub))
        cd exploded_epub do
          files = FileList["**/*"]
          files.exclude("mimetype")
          sh "zip -X -r #{target} mimetype #{files}"
        end
      end

      directory exploded_epub => pristine_epub do |t|
        rm_rf exploded_epub if File.exist?(exploded_epub)
        mkdir_p exploded_epub
        sh *%W[unzip #{pristine_epub} -d #{exploded_epub}]
      end

      file pristine_epub => [
        main.master_file,
        main.assets_file,
        main.deliverable_dir,
        stylesheet,
        metadata_file,
        *font_files
      ] do |t|
        create_epub_file(
          t.name,
          main.master_file,
          stylesheet: stylesheet,
          metadata_file: metadata_file,
          font_files: font_files)
      end

      file stylesheet => [pandoc_epub_dir, *main.stylesheets, fonts_stylesheet] do |t|
        sh "cat #{main.stylesheets} #{fonts_stylesheet} > #{t.name}"
      end

      file fonts_stylesheet do |t|
        create_fonts_stylesheet(t.name)
      end

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
      pandoc_flags = flags.dup
      master_dir = master_file.pathmap("%d")
      epub_file = Pathname(epub_file)
        .relative_path_from(Pathname(master_dir))
        .to_s
      if options[:stylesheet]
        stylesheet_file = Pathname(options[:stylesheet])
          .relative_path_from(Pathname(master_dir))
        pandoc_flags.concat(%W[--epub-stylesheet #{stylesheet_file}])
      end
      font_files.each do |font_file|
        font_path = Pathname(font_file).relative_path_from(Pathname(master_dir))
        pandoc_flags.concat(%W[--epub-embed-font #{font_path}])
      end
      metadata_path =
        Pathname(metadata_file).relative_path_from(Pathname(master_dir))
      pandoc_flags.concat(%W[--epub-metadata #{metadata_path}])
      cd master_dir do
        sh pandoc, "-o", epub_file, master_file.pathmap("%f"), *pandoc_flags
      end
    end

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

    def create_fonts_stylesheet(file=fonts_stylesheet)
      puts "generate #{file}"
      open(file, 'w') do |f|
        fonts.each do |font|
          f.puts(font.to_font_face_rule)
        end
      end
    end

    # Replace Pandoc mimetypes with the ones recognized by the IDPF
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

    def epub_file
      "#{main.deliverable_dir}/#{main.name}.epub"
    end

    def stylesheet
      "#{pandoc_epub_dir}/stylesheet.css"
    end

    def exploded_epub
      "#{pandoc_epub_dir}/book"
    end

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
