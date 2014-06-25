require "quarto/plugin"
require "quarto/template"

module Quarto
  class TemplateSet < Plugin
    include PathHelpers

    module BuildExt
      attr_accessor :templates
    end

    def enhance_build(build)
      build.extend(BuildExt)
      build.templates = self
    end

    def define_tasks
    end

    def generate_file_from_template(file, template,
                                    root_dir: main.build_dir,
                                    layout: nil)
      template = Template.new(template, main)
      mkpath file.pathmap("%d")
      if template.final?
        cp template, file
      else
        expand_template(template, file, root_dir: root_dir, layout: layout)
      end
    end

    def expand_template(input, output,
                        root_dir: main.build_dir,
                        layout: nil,
                        ** locals,
                        &block)
      layout_template =
          layout &&
              input.html? &&
              Template.new(find_template_for("#{main.build_dir}/#{layout}"),
                           main)
      if layout_template
        say "expand #{input.path} -> #{output} (layout: #{layout_template.path})"
      else
        say "expand #{input.path} -> #{output}"
      end
      content = input.render(main,
                             layout:   layout_template,
                             root_dir: root_dir,
                             ** locals,
                             &block)
      mkpath output.pathmap("%d")
      open(output, "w") do |f|
        f.write(content)
      end
    end

    def find_template_for(path)
      logical_path = rel_path(path, main.build_dir)
      find_user_template_for(logical_path) ||
          find_system_template_for(logical_path) or
          raise "No template found for resource #{path}"
    end

    def find_user_template_for(path)
      FileList["#{user_template_dir}/#{path}*"].first
    end

    def find_system_template_for(path)
      FileList["#{system_template_dir}/#{path}*"].first
    end

    def make_template(path)
      Template.new(path, main)
    end

    def system_template_dir
      main.system_template_dir
    end

    def user_template_dir
      template_dir
    end

    def template_expansion_dir
      main.template_build_dir
    end

    def template_dir
      "templates"
    end

    def system_template_dir
      File.expand_path("../../../templates", __FILE__)
    end
  end
end
