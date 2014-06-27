require "quarto/path_helpers"
require "tilt"
require "slim"

Tilt.register(Slim::Template, "slim")

module Quarto
  class Template
    RenderContext = Struct.new(:build, :layout, :root_dir) do
      def render(template, **locals, &block)
        path     = "#{root_dir}/#{template}"
        template = Template.new(build.templates.find_template_for(path), build)
        template.render(build,
                        root_dir: root_dir,
                        render_context: self,
                        **locals,
                        &block)
      end
    end

    include PathHelpers

    attr_reader :path

    def initialize(path, build)
      @path  = path
      @build = build
    end

    def to_path
      path
    end

    def to_str
      path
    end

    def to_s
      "#<#{self.class}:#{path}>"
    end

    def final?
      tilt_template = Tilt[path]
      tilt_template.nil? || tilt_template == Tilt::PlainTemplate
    end

    def html?
      path.pathmap("%f") =~ /\.html\b/
    end

    def render(
        build,
        layout:         nil,
        root_dir: build.build_dir,
        render_context: RenderContext.new(build, layout, root_dir),
        **locals,
        &block)
      tilt_template = Tilt.new(path, **tilt_template_options(path))
      content       = tilt_template.render(render_context, locals, &block)
      if layout
        layout.render(build,
                      root_dir: root_dir,
                      render_context: render_context,
                      **locals) do
          content
        end
      else
        content
      end
    end

    def tilt_template_options(path)
      case path.pathmap("%x")
      when ".slim" then {format: :html5, pretty: true}
      when ".scss" then scss_options
      else {}
      end
    end

    def scss_options
      {
          load_paths: [@build.stylesheets.templates_dir]
      }
    end
  end
end
