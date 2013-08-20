require "quarto/plugin"
require "nokogiri"

module Quarto
  class PandocEpub < Plugin
    module BuildExt
      extend Forwardable

      attr_accessor :pandoc_epub
    end

    fattr(:flags) { %W[-w epub3 --epub-chapter-level 2 --no-highlight --toc --parse-raw] }
    fattr(:xml_write_options) {
      Nokogiri::XML::Node::SaveOptions::DEFAULT_XHTML |
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
        target = Pathname(t.name).relative_path_from(Pathname(exploded_epub))
        cd exploded_epub do

          sh "zip -r #{target} *"
        end
      end

      directory exploded_epub => pristine_epub do |t|
        rm_rf exploded_epub if File.exist?(exploded_epub)
        mkdir_p exploded_epub
        sh *%W[unzip #{pristine_epub} -d #{exploded_epub}]
      end

      file pristine_epub => [main.master_file, main.deliverable_dir, stylesheet] do |t|
        create_epub_file(t.name, main.master_file, stylesheet: stylesheet)
      end

      file stylesheet => [pandoc_epub_dir, *main.stylesheets] do |t|
        sh "cat #{main.stylesheets} > #{t.name}"
      end

      directory pandoc_epub_dir
    end

    private

    def create_epub_file(epub_file, master_file, options={})
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
      cd master_dir do
        sh pandoc, "-o", epub_file, master_file.pathmap("%f"), *pandoc_flags
      end
    end

    def replace_listings(epub_dir, highlights_dir)
      files = FileList["#{epub_dir}/**/*.xhtml"]
      files.each do |file|
        doc = open(file) { |f|
          Nokogiri::HTML(f)
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
            puts code
            puts "----"
          end
        end
        open(file, 'w') do |f|
          doc.write_xml_to(f, save_with: xml_write_options)
        end
        sh "grep -v '^<?xml' #{file} > #{file}"
      end
    end

    def epub_file
      "#{main.deliverable_dir}/book.epub"
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

  end
end
