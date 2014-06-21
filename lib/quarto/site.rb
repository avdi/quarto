require "quarto/plugin"
require "quarto/path_helpers"
require "quarto/template"
require "tilt"

module Quarto
  class Site < Plugin
    include PathHelpers

    module BuildExt
      attr_accessor :site
    end

    class ResourceTemplateFinder
      def initialize(site)
        @site = site
      end

      def call(resource)
      end
    end

    attr_reader :bower_deps, :resources

    def initialize(*)
      super
      @bower_deps        = []
      @resources             = []
      add_resource "index.html"
    end

    def enhance_build(build)
      build.extend(BuildExt)
      build.site = self
    end

    def define_tasks
      namespace :site do
        desc "Build a website for the book"
        task :build => ["fascicles", site_dir, "site:resources", "bower:install"]

        desc "Deploy the book website"
        task :deploy => :build

        directory site_dir
        directory site_template_dir

        task "resources" do
          resources.each do |resource|
            Rake.application[resource].invoke
          end

          main.fascicles.each do |fascicle|
            site_path = site_fascicle_path(fascicle)
            deps = [fascicle.path, fascicle_template_path]
            Rake.application.define_task(Rake::FileTask, site_path => deps) do
              generate_fascicle_page(fascicle, site_path)
            end.invoke
          end
        end

        namespace :bower do
          desc "Install Bower dependencies"
          task :install => [bower_config_file, bower_package_file] do
            bower_deps.each do |dep|
              cd site_dir do
                sh "bower install -S #{dep}"
              end
            end
          end
        end

        rule %r(#{site_dir}/.*) => method(:find_template_for) do |t|
          generate_resource_from_template(t.name, t.source)
        end
      end

    end

    def page_list
      "#{main.build_dir}/site-page-list.rake"
    end

    def add_resource(resource)
      resources << "#{site_dir}/#{resource}"
    end

    def find_template_for(path)
      logical_path = rel_path(path, build_dir)
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

    def fascicle_template_path
      find_template_for("#{site_dir}/_fascicle.html")
    end

    def find_fascicle_file_for(path)
      numbered_name = path.pathmap("%f")
      FileList["#{main.fascicle_dir}/#{numbered_name}.xhtml"].first or
        raise "Unable to find fascicle corresponding to #{path}"
    end

    def generate_resource_from_template(resource, template)
      template = Template.new(template)
      mkpath resource.pathmap("%d")
      if template.final?
        cp template, resource
      else
        expand_template(template, resource)
      end
    end

    def expand_template(input, output, **locals, &block)
      say "expand #{input.path} -> #{output}"
      content = input.render(main, **locals, &block)
      open(output, "w") do |f|
        f.write(content)
      end
    end

    def add_bower_dep(package)
      bower_deps << package
    end

    def site_dir
      "#{main.build_dir}/site"
    end

    fattr(:site_template_dir) { "#{main.template_dir}/site" }

    def site_fascicle_dir
      "#{site_dir}/fascicles"
    end

    def bower_config_file
      "#{site_dir}/.bowerrc"
    end

    def bower_package_file
      "#{site_dir}/bower.json"
    end

    def system_template_dir
      main.system_template_dir
    end

    def user_template_dir
      main.template_dir
    end

    def template_expansion_dir
      main.template_build_dir
    end

    def build_dir
      main.build_dir
    end

    def site_fascicle_path(fascicle)
      "#{site_fascicle_dir}/#{fascicle.numbered_name}.html"
    end

    def fascicle_url(fascicle)
      "/fascicles/#{fascicle.numbered_name}.html"
    end

    def generate_fascicle_page(fascicle, path)
      fasc_doc  = open(fascicle.path) do |f| Nokogiri::XML(f) end
      content   = fasc_doc.at_css("div.fascicle").children
      template  = Template.new(fascicle_template_path)
      expand_template(template, path, fascicle: fascicle) do
        content.to_html
      end
    end
  end
end
