require "quarto/path_helpers"
require "tilt"

module Quarto
  class Template
    RenderContext = Struct.new(:build, :layout) do
      def render(resource, **locals, &block)
        path     = "#{build.site.site_dir}/#{resource}"
        template = Template.new(build.site.find_template_for(path))
        template.render(build, render_context: self, **locals, &block)
      end
    end

    include PathHelpers

    attr_reader :path

    def initialize(path)
      @path = path
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
      tilt_templates = Tilt.templates_for(path)
      tilt_templates.empty? || tilt_templates == [Tilt::PlainTemplate]
    end

    def html?
      path.pathmap("%f") =~ /\.html\b/
    end

    def render(
        build,
        layout:         nil,
        render_context: RenderContext.new(build, layout),
        **locals,
        &block)
      tilt_template = Tilt.new(path, format: :html5, pretty: true)
      content       = tilt_template.render(render_context, locals, &block)
      if layout
        layout.render(build, render_context: render_context, **locals) do
          content
        end
      else
        content
      end
    end
  end
end
