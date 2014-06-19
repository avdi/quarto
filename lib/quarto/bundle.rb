require "quarto/plugin"

module Quarto
  class Bundle < Plugin
    def define_tasks
      desc "Build a bundle"
      task :bundle => bundle_file

      task :deliverables => :bundle


      file bundle_file => main.deliverable_files do |t|
        cd main.deliverable_dir do
          sh "zip -r #{t.name.pathmap("%f")} #{main.deliverable_files.pathmap('%f')}"
        end
      end
    end

    private

    def bundle_file
      "#{main.deliverable_dir}/#{main.name}.zip"
    end
  end
end
