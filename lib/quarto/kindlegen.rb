require "quarto/plugin"

module Quarto
  class Kindlegen < Plugin
    def define_tasks
      task :deliverables => kf8_file

      desc "Generate a Kindle file"
      task :kindlegen => kf8_file

      directory kindlegen_dir

      file kf8_file => [kindlegen_dir, epub_file] do |t|
        sh *%W[kindlegen #{epub_file} -o #{kf8_file.pathmap("%f")}] do
          # Ignore warning for now
        end
      end
    end

    private

    def kf8_file
      "#{kindlegen_dir}/#{main.name}.kf8"
    end

    def epub_file
      main.epub_file
    end

    def kindlegen_dir
      "#{main.deliverable_dir}/kindlegen"
    end
  end
end
