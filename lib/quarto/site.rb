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

    ExpansionContext = Struct.new(:build) do
      def render(template, **options, &block)
        build.site.render_template(template, **options, &block)
      end
    end

    attr_reader :bower_deps, :system_templates

    def initialize(*)
      super
      @bower_deps        = []
      @system_templates  = []
      add_system_template rel_path(bower_config_file, "build")
      add_system_template rel_path(bower_package_file, "build")
      add_system_template fascicle_template
      add_system_template main_layout
      add_system_template "site/_toc.html"
      add_system_template "site/_book_metadata.html"
      add_system_template "site/index.html"
    end

    def add_system_template(logical_path, **options)
      template = Template.new(logical_path, self, **options)
      unless template.available_from_system?
        fail "No system template found: #{logical_path}"
      end
      @system_templates << template
    end

    def enhance_build(build)
      build.extend(BuildExt)
      build.site = self
    end

    def define_tasks
      namespace :templates do
        task :populate

        templates.select(&:complete?).each do |template|
          generate_deps_for_template(template)
        end
      end

      namespace :site do
        desc "Build a website for the book"
        task :build => ["templates:populate", site_dir, *site_files, "bower:install"]

        desc "Deploy the book website"
        task :deploy => :build


        directory site_dir
        directory site_template_dir

        file toc_partial => [
          main.fascicle_manifest,
          template_path(fascicle_template),
          template_path(main_layout)] do

          generate_fascicle_pages(main.fascicle_manifest, toc_partial)
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
      end
    end

    def add_bower_dep(package)
      bower_deps << package
    end

    def site_dir
      "#{main.build_dir}/site"
    end

    fattr(:site_template_dir) { "#{main.template_dir}/site" }

    def site_files
      site_template_files.map{|f| site_file_for_template_file(f)}
    end

    def templates
      system_templates | user_templates
    end

    def user_templates
      @user_templates ||= find_user_templates
    end

    def find_user_templates
      starts_with_noise = /^[^_\.[:alnum:]]/
      ends_with_noise   = /[^[:alnum:]]$/
      files = FileList["#{main.template_dir}/**/*"].exclude do |path|
        File.directory?(path) ||
        path.pathmap("%f") =~ starts_with_noise ||
          path.pathmap("%f") =~ ends_with_noise
      end
      files.map {|template_file|
        logical_path = template_file.sub(/^#{main.template_dir}\//,"")
        Template.new(logical_path, self)
      }
    end

    def site_template_files
      starts_with_noise = /^[^\.[:alnum:]]/
      ends_with_noise   = /[^[:alnum:]]$/
      FileList["#{site_template_dir}/**/*"].exclude do |path|
        File.directory?(path) ||
        path.pathmap("%f") =~ starts_with_noise ||
          path.pathmap("%f") =~ ends_with_noise
      end
    end

    def site_fascicle_dir
      "#{site_dir}/fascicles"
    end

    def toc_partial
      "#{site_template_dir}/_toc.html"
    end

    def site_file_for_template_file(filename)
      filename = pop_ext(filename) until filename.nil? || has_final_ext?(filename)
      filename = rel_path(filename, site_template_dir)
      "#{site_dir}/#{filename}"
    end

    def bower_config_file
      "#{site_dir}/.bowerrc"
    end

    def bower_package_file
      "#{site_dir}/bower.json"
    end

    def pop_ext(file)
      file[0...file.rindex(".")]
    end

    def has_final_ext?(filename)
      ext = filename.pathmap("%x")[1..-1].to_s.downcase
      ext.empty? || ext == "html" || !Tilt.registered?(ext)
    end

    def template_file(base_path)
      rel_dir              = base_path.pathmap("%d")
      user_template_path   = user_template_for(base_path)
      system_template_path = system_template_for(base_path) or
        fail "No system template found for #{base_path}"

      unless user_template_path
        user_template_path =
          user_template_path_for_system_template_path(system_template_path)
        file user_template_path => system_template_path do
          mkpath user_template_path.pathmap("%d")
          cp system_template_path, user_template_path
        end
      end

      generate_deps_for_template(user_template_path, layout: nil)

      Rake::Task["templates:populate"].enhance([user_template_path])
    end

    def generate_deps_for_template(template)
      metamorphoses = template.metamorphoses
      metamorphoses.each_cons(2) do |input_file, output_file|
        file output_file => input_file do
          expand_template(input_file, output_file)
        end
      end
    end

    def generate_deps_for_template_file(template_file, layout: "site/layouts/_main.html")
      dir             = main.template_dir
      rel_dir         = rel_path(template_file, dir).pathmap("%d")
      input_path      = template_file
      work_dir        = "#{main.template_build_dir}/#{rel_dir}"
      work_dir        = Pathname(work_dir).cleanpath.to_s
      until has_final_ext?(input_path)
        output_name = pop_ext(input_path.pathmap("%f"))
        output_path = "#{work_dir}/#{output_name}"

        file output_path => input_path do
          expand_template(input_path, output_path)
        end

        input_path = output_path
      end
      final_dir  = clean_path("#{main.build_dir}/#{rel_dir}")
      final_path = "#{final_dir}/#{input_path.pathmap("%f")}"

      layout_file = if layout && final_path.pathmap("%x").downcase == ".html"
                      existing_template_path(layout)
                    else
                      nil
                    end

      file final_path => [input_path, layout_file].compact do
        expand_template(input_path, final_path, layout_file: layout_file)
      end
    end

    def expand_template(input_file, output_file, layout_file: nil, locals: {}, &block)
      mkpath(output_file.pathmap("%d"))
      if has_final_ext?(input_file)
        cp input_file, output_file
      else
        context         = ExpansionContext.new(main)
        template        = Tilt.new(input_file)
        if layout_file
          say "expand #{input_file} -> #{output_file} (layout: #{layout_file})"
          layout = Tilt.new(layout_file)
          output = layout.render(context, locals) do
            template.render(context, locals, &block)
          end
        else
          say "expand #{input_file} -> #{output_file}"
          output = template.render(context, locals, &block)
        end
        File.write(output_file, output)
      end
    end

    def render_template(template_name, **locals, &block)
      template_file    = existing_template_path(template_name)
      context          = ExpansionContext.new(main)
      template         = Tilt.new(template_file)
      template.render(context, locals, &block)
    end

    def template_path(logical_path)
      template = templates.detect{|t| t.logical_path == logical_path} or
        fail "No template found for #{logical_path}"
      template.concrete_path
    end

    def existing_template_path(template)
      template_path(template).tap do |p|
        File.exist?(p) or fail "Template #{template} does not exist!"
      end
    end

    def user_template_path_for_system_template_path(sys_path)
      rel = rel_path(sys_path, main.system_template_dir)
      clean_path("#{main.template_dir}/#{rel}")
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

    def main_layout
      "site/layouts/_main.html"
    end

    def fascicle_template
      "site/_fascicle.html"
    end

    def generate_fascicle_pages(fascicle_manifest)
      fascicle_files = File.read(fascicle_manifest).split
      toc = Nokogiri::HTML::Document.new.fragment
      fascicle_files.each_with_index do |fasc_file, index|
        fasc_doc  = open(fasc_file) do |f| Nokogiri::XML(f) end
        title     = fasc_doc.at_css("title").text
        name      = fasc_file.pathmap("%n")
        content   = fasc_doc.at_css("div.fascicle").children
        path      = "#{site_fascicle_dir}/#{name}.html"
        site_path = rel_path(path, site_dir)
        toc.add_child("<li><a href='/#{site_path}'>#{title}</a></li>")
        locals    = { title: title, name: name, fascicle_number: index + 1 }
        generate_page(path, template: fascicle_template, locals: locals) do
          content.to_html
        end
      end
      open(toc_partial, "w") do |f|
        f.write(toc.children.to_html)
      end
    end

    def generate_page(path,
        template: "site/_page",
        layout: "site/layouts/_main",
        locals: {},
        &block)
      template_file = existing_template_path(template) or
        fail "Template not found: #{template}"
      layout_file   = existing_template_path(layout) or
        fail "Layout not found: #{layout}"
      expand_template(
        template_file,
        path,
        layout_file: layout_file,
        locals: locals,
        &block)
    end
  end
end
