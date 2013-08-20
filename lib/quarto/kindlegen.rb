require "quarto/plugin"

module Quarto
  class Kindlegen < Plugin
    def enhance_build(build)
      build.deliverable_files << kf8_file
    end

    def define_tasks
      desc "Generate a Kindle file"
      task :kindlegen => kf8_file

      file kf8_file => epub_file do |t|
        sh *%W[kindlegen #{epub_file} -o #{kf8_file.pathmap("%f")}] do
          # Ignore warning for now
        end
      end
    end

    private

    def kf8_file
      "#{main.deliverable_dir}/#{main.name}.mobi"
    end

    def epub_file
      "#{main.deliverable_dir}/#{main.name}.epub"
    end
  end
end
