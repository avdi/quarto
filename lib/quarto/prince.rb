require "quarto/plugin"

module Quarto
  class Prince < Plugin
    module BuildExt
      fattr(:prince)
    end

    fattr(:cover_image)

    def enhance_build(build)
      build.deliverable_files << pdf_file
      build.extend(BuildExt)
      build.prince = self
    end

    def define_tasks
      file pdf_file => [prince_master_file, main.assets_file] do |t|
        mkdir_p t.name.pathmap("%d")
        sh *%W[prince #{prince_master_file} -o #{t.name}]
      end

      file prince_master_file => [main.master_file] do |t|
        create_prince_master_file(prince_master_file, main.master_file)
      end
    end

    def pdf_file
      "#{main.deliverable_dir}/book.pdf"
    end

    def prince_master_file
      "#{main.master_dir}/prince_master.xhtml"
    end

    def create_prince_master_file(prince_master_file, master_file)
      doc = open(master_file) { |f|
        Nokogiri::XML(f)
      }
      body_elt = doc.root.at_css("body")
      body_elt.first_element_child.before("<div class='frontcover'></div>")
      open(prince_master_file, 'w') do |f|
        doc.write_xml_to(f)
      end
    end
  end
end
