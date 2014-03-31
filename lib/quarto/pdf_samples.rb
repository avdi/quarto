require "quarto/plugin"
require "forwardable"

module Quarto
  # The PdfSamples plugin enables users to generate sample PDFs that
  # are based on selected pages from the final PDF deliverable.
  class PdfSamples < Plugin
    module BuildExt
      fattr(:pdf_samples)
      def add_pdf_sample(**options)
        pdf_samples.add(**options)
      end
    end

    SampleDef = Struct.new(:name, :selections, :description)

    def enhance_build(build)
      build.extend(BuildExt)
      build.pdf_samples = self
    end

    def define_tasks
      task :deliverables => :pdf_samples

      desc "Generate PDF sample files from the PDF book file"
      task :pdf_samples => pdf_sample_files

      directory sample_dir

      sample_defs.each do |sample|
        file sample_path(sample.name) => [standalone_pdf_file, sample_dir] do
          extract_sample(standalone_pdf_file, sample_path(sample.name), *sample.selections)
        end
      end
    end

    def standalone_pdf_file
      main.standalone_pdf_file
    end

    def sample_defs
      @samples ||= []
    end

    def add(name:, select:, desc: "")
      sample_def = SampleDef.new(name, select, desc)
      sample_defs << sample_def
    end

    def extract_sample(source_pdf, sample_path, *selections)
      selection_flags = pdftk_selection_flags("A", *selections)
      sh "pdftk A=#{source_pdf} cat #{selection_flags} output #{sample_path}"
    end

    def pdftk_selection_flags(handle, *selections)
      flags = selections.map { |selection|
        case selection
        when Integer then selection.to_s
        when Range
          "#{selection.first.to_i}-#{selection.last.to_i}"
        end
      }
      flags.map{|flag| "#{handle}#{flag}"}.join(" ")
    end

    def pdf_sample_files
      sample_defs.map{|sample| sample_path(sample.name)}
    end

    def sample_path(sample_name)
      "#{sample_dir}/#{sample_name}.pdf"
    end

    def sample_dir
      "#{main.build_dir}/pdf_samples"
    end
  end
end
