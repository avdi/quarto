require "quarto/plugin"

module Quarto
  class CalibreMobi < Plugin
    def enhance_build(build)
      build.deliverable_files << mobi_file
    end

    def define_tasks
      desc "Generate a Mobi (Kindle) file from EPUB file"
      task :mobi => mobi_file

      file mobi_file => epub_file do
        convert_epub_to_mobi(epub_file, mobi_file)
      end
    end

    def mobi_file
      "#{main.deliverable_dir}/#{main.name}.mobi"
    end

    def epub_file
      main.epub_file
    end

    def calibre_flags
      %W[--mobi-file-type=both]
    end

    def convert_epub_to_mobi(epub_file, mobi_file)
      sh "ebook-convert #{epub_file} #{mobi_file} #{calibre_flags.join(' ')}"
    end
  end
end
