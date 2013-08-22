require "quarto/prince"
require "doc_raptor"

module Quarto
  class DocRaptor < Prince
    private

    def generate_pdf_file(pdf_file, master_file)
      test_mode = ENV["QUARTO_ENV"] == "production" ? false : true
      puts "create #{pdf_file} using DocRaptor (test: #{test_mode})"
      ::DocRaptor.create(
        document_content: File.read(master_file),
        name: master_file.pathmap("%f"),
        document_type: "pdf",
        test: test_mode,
        prince_options: {input: "xml"}) do |file, response|

        if response.code.to_i == 200
          open(pdf_file, 'w') do |pdf|
            IO.copy_stream(file, pdf)
          end
        else
          puts "Error #{response.code}: #{response.message}"
          puts file.read
        end
      end
    end

    def prince_dir
      "#{main.build_dir}/doc_raptor"
    end

    def prince_master_file
      "#{main.master_dir}/prince_master.xhtml"
    end
  end
end
