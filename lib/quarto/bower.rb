require "quarto/plugin"

module Quarto
  class Bower < Plugin
    module BuildExt
      attr_accessor :bower
    end

    attr_reader :deps

    def initialize(*)
      super
      @deps = []
    end

    def enhance_build(build)
      build.require_plugin(:template_set)
      build.extend(BuildExt)
      build.bower = self
    end

    def define_tasks
      namespace :bower do
        desc "Install Bower dependencies"
        task :install => [config_file, package_file] do
          deps.each do |dep|
            cd site_dir do
              sh "bower install -S #{dep}"
            end
          end
        end
      end
    end

    def add_dep(package)
      deps << package
    end

    def config_file
      "#{main.build_dir}/.bowerrc"
    end

    def package_file
      "#{main.build_dir}/bower.json"
    end
  end
end
