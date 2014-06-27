require "quarto/plugin"
require "quarto/template"
require "pathname"

module Quarto
  class TemplateSet < Plugin
    include PathHelpers

    module BuildExt
      attr_accessor :templates
    end

    UNMET_DEPENDENCY = ["<<DOESNOTEXIST>>"]

    def enhance_build(build)
      build.extend(BuildExt)
      build.templates = self
    end

    def define_tasks
      rule %r(#{main.build_dir}/.*) => method(:find_template_deps_for) do |t|
        generate_file_from_template(t.name, t.source,
                                    root_dir: main.build_dir)
      end
    end

    def generate_file_from_template(file, template,
                                    root_dir: main.build_dir,
                                    layout: true)
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
      layout_file =
        case layout
        when true then find_layout_for(output)
        when String then find_template_for("#{main.build_dir}/#{layout}")
        else nil
        end
      layout_template = layout_file && Template.new(layout_file, main)
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

    def find_template_deps_for(path)
      return UNMET_DEPENDENCY if dependency_blacklist.include?(path)
      find_template_for(path) { [] }
    end

    # Search upwards until we find a _layout.* file corresponding to `path`.
    def find_layout_for(path)
      ext = File.extname(path)
      upwards_find_template_for(path.pathmap("%d/_layout#{ext}"))
    end

    # Search upwards until we find a template corresponding to target `path`.
    def upwards_find_template_for(path)
      path = Pathname(path)
      base = path.basename
      path.dirname.ascend do |dir|
        if template = find_template_for((dir + base).to_s){nil}
          return template
        end
        return nil if dir.to_s == main.build_dir
      end
      nil
    end

    # Look up the path of a template corresponding to the given target path.
    # Favors user templates over system templates.
    #
    # @yield if no template is found
    # @raise [RuntimeError] if no template is found and no block provided
    def find_template_for(path)
      logical_path = rel_path(path, main.build_dir)
      template = find_user_template_for(logical_path) ||
            find_system_template_for(logical_path)
      template or if block_given? then yield
                  else raise "No template found for resource #{path}"
                  end
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

    def do_not_generate_deps_for(path)
      self.dependency_blacklist << path
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

    def dependency_blacklist
      @dependency_blacklist ||= []
    end
  end
end
