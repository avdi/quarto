require "quarto/plugin"
require "quarto/uri_helpers"
require "mime/types"
require "uri"

module Quarto
  class Prince < Plugin
    include UriHelpers

    module BuildExt
      fattr(:prince)
      def standalone_pdf_file
        prince.standalone_pdf_file
      end
    end

    fattr(:cover_image)
    fattr(:xml_write_options) {
      Nokogiri::XML::Node::SaveOptions::DEFAULT_XML |
      Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
    }

    def enhance_build(build)
      build.deliverable_files << standalone_pdf_file
      build.extend(BuildExt)
      build.prince = self
    end

    def define_tasks
      task :deliverables => :pdf

      desc "Build a PDF with PrinceXML"
      task :pdf => :"prince:pdf"

      namespace :prince do
        task :pdf => pdf_files
      end

      file standalone_pdf_file => [prince_master_file] do |t|
        mkdir_p t.name.pathmap("%d")
        generate_pdf_file(standalone_pdf_file, prince_master_file)
      end

      file interior_pdf_file => [prince_interior_master_file] do |t|
        mkdir_p t.name.pathmap("%d")
        generate_pdf_file(interior_pdf_file, prince_interior_master_file)
      end

      file prince_master_file => [main.master_file, main.assets_file, toc_file, stylesheet] do |t|
        create_prince_master_file(prince_master_file,main.master_file, stylesheet, cover: true)
      end

      file prince_interior_master_file =>
        [main.master_file, main.assets_file, toc_file, stylesheet] do |t|
        create_prince_master_file(prince_interior_master_file, main.master_file, stylesheet, cover: false)
      end

      file toc_file => [main.master_file, prince_dir] do |t|
        generate_cmd = "pandoc --table-of-contents --standalone #{main.master_file}"
        toc_xpath    = "//*[@id='TOC']"
        extract_cmd  = %Q(xmlstarlet sel -I -t -c "#{toc_xpath}")
        sh "#{generate_cmd} | #{extract_cmd} > #{t.name}"
      end

      file stylesheet => pdf_stylesheets do |t|
        sh "cat #{pdf_stylesheets} > #{t.name}"
      end

      file font_stylesheet do |t|
        puts "generate #{t.name}"
        open(t.name, 'w') do |f|
          main.fonts.each do |font|
            f.puts(font.to_font_face_rule(embed: true))
          end
        end
      end

      directory prince_dir
    end

    def pdf_files
      [standalone_pdf_file, interior_pdf_file]
    end

    def standalone_pdf_file
      "#{main.deliverable_dir}/#{main.name}.pdf"
    end

    def interior_pdf_file
      "#{main.deliverable_dir}/#{main.name}-interior.pdf"
    end

    def prince_master_file
      "#{main.master_dir}/prince_master.xhtml"
    end

    def prince_interior_master_file
      "#{main.master_dir}/prince_interior_master.xhtml"
    end

    def toc_file
      "#{prince_dir}/toc.xml"
    end

    def stylesheet
      "#{prince_dir}/styles.css"
    end

    def pdf_stylesheets
      main.stylesheets.applicable_to(:pdf).master_files + FileList[font_stylesheet]
    end

    def font_stylesheet
      "#{prince_dir}/fonts.css"
    end

    def prince_dir
      "#{main.build_dir}/prince"
    end

    def create_prince_master_file(prince_master_file, master_file, stylesheet, options={})
      puts "create #{prince_master_file} from #{master_file}"
      doc = open(master_file) { |f|
        Nokogiri::XML(f)
      }
      body_elt = doc.root.at_css("body")
      first_child = body_elt.first_element_child
      if options.fetch(:cover){true} && main.bitmap_cover_image
        cover_image_uri = data_uri_for_file(main.bitmap_cover_image)
        first_child.before(
          "<div class='frontcover'><img src='#{cover_image_uri}'/></div>")
      end
      first_child.before(File.read(toc_file))
      doc.at_css("#TOC").first_element_child.before("<h1>Table of Contents</h1>")
      doc.css("link[rel='stylesheet']").remove
      doc.at_css("head").add_child(
        doc.create_element("style") do |elt|
          elt["type"] = "text/css"
          elt.content = File.read(stylesheet)
        end)
      embed_images(doc)
      open(prince_master_file, 'w') do |f|
        doc.write_xml_to(f, save_with: xml_write_options)
      end
    end

    def embed_images(doc)
      doc.css("img").each do |elt|
        uri = URI.parse(elt["src"])
        if !uri.scheme && File.exist?(uri.path)
          elt["src"] = data_uri_for_file(uri.path)
        end
      end
    end

    def generate_pdf_file(pdf_file, master_file)
      sh *%W[prince #{master_file} -o #{pdf_file}]
    end
  end
end
