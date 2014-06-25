require "quarto/plugin"
require "quarto/path_helpers"
require "quarto/template"
require "tilt"
require "forwardable"

module Quarto
  class Site < Plugin
    include PathHelpers
    extend Forwardable

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
      @bower_deps = []
      @resources  = []
      add_resource "index.html"
    end

    def enhance_build(build)
      build.require_plugin(:template_set)
      build.extend(BuildExt)
      build.site = self
    end

    def define_tasks
      task :default => :site

      desc "Build a website for the book"
      task :site => "site:build"

      namespace :site do
        task :build => ["fascicles", site_dir, "site:resources", "bower:install"]

        desc "Deploy the book website"
        task :deploy => :build

        desc "Start a simple server to test the site"
        task :serve do
          sh RUBY, *%W[-run -e httpd #{site_dir} -p 9090]
        end

        directory site_dir
        directory site_template_dir

        task "resources" do
          layout_file =
              templates.find_template_for("#{main.build_dir}/#{default_layout}")

          resources.each do |resource|
            task = Rake.application[resource]
            task.enhance([layout_file])
            task.invoke
          end

          main.fascicles.each do |fascicle|
            site_path = site_fascicle_path(fascicle)
            deps      = [fascicle.path, fascicle_template_path]
            task      = Rake.application.define_task(Rake::FileTask, site_path => deps) do
              generate_fascicle_page(fascicle, site_path)
            end
            task.enhance([layout_file])
            task.invoke
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

        rule %r(#{site_dir}/.*) => templates.method(:find_template_for) do |t|
          templates.generate_file_from_template(t.name, t.source,
                                                root_dir: site_dir,
                                                layout:   default_layout)
        end
      end

    end

    def page_list
      "#{main.build_dir}/site-page-list.rake"
    end

    def add_resource(resource)
      resources << "#{site_dir}/#{resource}"
    end

    def fascicle_template_path
      templates.find_template_for("#{site_dir}/_fascicle.html")
    end

    def find_fascicle_file_for(path)
      numbered_name = path.pathmap("%f")
      FileList["#{main.fascicle_dir}/#{numbered_name}.xhtml"].first or
          fail "Unable to find fascicle corresponding to #{path}"
    end

    def default_layout
      "site/_layout.html"
    end

    def add_bower_dep(package)
      bower_deps << package
    end

    def site_dir
      "#{main.build_dir}/site"
    end

    fattr(:site_template_dir) { "#{templates.template_dir}/site" }

    def site_fascicle_dir
      "#{site_dir}/fascicles"
    end

    def bower_config_file
      "#{site_dir}/.bowerrc"
    end

    def bower_package_file
      "#{site_dir}/bower.json"
    end

    def site_fascicle_path(fascicle)
      "#{site_fascicle_dir}/#{fascicle.numbered_name}.html"
    end

    def fascicle_url(fascicle)
      "/fascicles/#{fascicle.numbered_name}.html"
    end

    def generate_fascicle_page(fascicle, path)
      fasc_doc = open(fascicle.path) do |f|
        Nokogiri::XML(f)
      end
      content  = fasc_doc.at_css("div.fascicle").children
      # TODO: Dingdingding feature envy!!!
      template = templates.make_template(fascicle_template_path)
      templates.expand_template(template, path,
                                root_dir: site_dir,
                                fascicle: fascicle,
                                layout: default_layout) do
        content.to_html
      end
    end

    private

    # @!method templates
    #   @return [TemplateSet]
    def_delegators :main, :templates
  end
end
