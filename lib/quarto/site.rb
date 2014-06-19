require "quarto/plugin"
require "quarto/path_helpers"
require "tilt"

module Quarto
  class Site < Plugin
    include PathHelpers

    module BuildExt
      attr_accessor :site
    end

    attr_reader :bower_deps

    def initialize(*)
      super
      @bower_deps = []
    end

    def enhance_build(build)
      build.extend(BuildExt)
      build.site = self
    end

    def define_tasks
      namespace :site do
        desc "Build a website for the book"
        task :build => [site_dir, *site_files, "bower:install"]

        desc "Deploy the book website"
        task :deploy => :build

        directory site_dir
        directory site_template_dir

        site_template_files.each do |source|
          generate_deps_for_template(source) do |output_file, input_file|
            p(output_file => input_file)
            file output_file => input_file do
              expand_template(input_file, output_file)
            end
          end
        end

        namespace :bower do
          desc "Install Bower dependencies"
          task :install do
            bower_deps.each do |dep|
              cd site_dir do
                sh "bower install #{dep}"
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

    def site_template_dir
      "#{main.template_dir}/site"
    end

    def site_files
      site_template_files.map{|f| site_file_for_template_file(f)}
    end

    def site_template_files
      starts_with_noise = /^[^[:alnum:]]/
      ends_with_noise   = /[^[:alnum:]]$/
      FileList["#{site_template_dir}/**/*"].
        exclude(starts_with_noise, ends_with_noise)
    end

    def site_file_for_template_file(filename)
      filename = pop_ext(filename) until filename.nil? || has_final_ext?(filename)
      filename = rel_path(filename, site_template_dir)
      "#{site_dir}/#{filename}"
    end

    def pop_ext(file)
      file[0...file.rindex(".")]
    end

    def has_final_ext?(filename)
      ext = filename.pathmap("%x")[1..-1].downcase
      ext == "html" || !Tilt.registered?(ext)
    end

    def generate_deps_for_template(template_file)
      dir             = main.template_dir
      rel_dir         = rel_path(template_file, dir).pathmap("%d")
      input_path      = template_file
      work_dir        = "#{main.template_build_dir}/#{rel_dir}"
      work_dir        = Pathname(work_dir).cleanpath.to_s
      until has_final_ext?(input_path)
        output_name = pop_ext(input_path.pathmap("%f"))
        output_path = "#{work_dir}/#{output_name}"
        yield(output_path, input_path)

        input_path = output_path
      end
      final_dir  = clean_path("#{main.build_dir}/#{rel_dir}")
      final_path = "#{final_dir}/#{input_path.pathmap("%f")}"
      yield(final_path, input_path)
    end

    def expand_template(input_file, output_file)
      mkpath(output_file.pathmap("%d"))
      if has_final_ext?(input_file)
        cp input_file, output_file
      else
        say "expand #{input_file} -> #{output_file}"
        template        = Tilt.new(input_file)
        output          = template.render(self)
        File.write(output_file, output)
      end
    end
  end
end
