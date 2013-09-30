require "quarto/plugin"
require "quarto/stylesheet"

module Quarto
  class StylesheetSet < Plugin
    include Enumerable

    module BuildExt
      fattr(:stylesheets)
      def clear_stylesheets
        stylesheets.remove_masters_from(all_master_files)
        stylesheets.clear
      end
    end

    NullStylesheet = Naught.build do |config|
      config.mimic Stylesheet
    end

    fattr(:font)                { 'serif' }
    fattr(:heading_font)        { '"PT Sans", sans-serif' }
    fattr(:heading_color)       { "black" }
    fattr(:left_slug)           { nil }
    fattr(:right_slug)          { nil }
    fattr(:print_page_width)    { "7.5in" }
    fattr(:print_page_height)   { "9in"   }
    fattr(:cover_color)         { "black" }

    def initialize(build, sheets=[])
      super(build)
      @sheets = sheets
    end

    def enhance_build(build)
      add("base.css")
      add("code.css")
      add("pages.css", targets: [:pdf])
      add("pdf.css", targets: [:pdf])
      add("epub2.css", targets: [:epub2])
      add("epub3.css", targets: [:epub3])
      build.extend(BuildExt)
      build.stylesheets = self
    end

    def finalize_build(build)
      build.all_master_files.include(master_files)
    end

    def each(&block)
      @sheets.each(&block)
    end

    def define_tasks
      file main.master_file => master_files

      namespace :stylesheets do
        task :sources => source_files
        task :masters => master_files
      end

      rule %r(\A#{source_dir}/.*\.s?css\z) => [
        ->(f){template_for_source(f)},
        source_dir,
        var_file
      ] do |t|
        sh "cat #{var_file} #{t.source} > #{t.name}"
      end

      rule %r(\A#{master_dir}/.*\.css\z) => [
        ->(f){source_for_master(f)},
        master_dir,
      ] do |t|
        if t.source.end_with?(".scss")
          sh "sass", *sass_load_paths.pathmap("-I%p"),
             *%W[--scss #{t.source} #{t.name}]
        else
          cp t.source, t.name
        end
      end

      file var_file => main.build_dir do |t|
        puts "write #{t.name}"
        open(t.name, 'w') do |f|
          write_scss_variables(f, variables)
        end
      end

      directory source_dir
      directory master_dir
    end

    def add(*args)
      @sheets << Stylesheet.new(self, *args)
    end

    def clear
      @sheets.clear
    end

    def remove_masters_from(list)
      master_files.each do |mf|
        list.delete(mf)
      end
    end

    def applicable_to(*targets)
      sheets = @sheets.select{|s| s.applicable_to_targets?(*targets)}
      self.class.new(main, sheets)
    end

    def generate_stylesheet_for_targets(io, *targets)
      applicable_to(*targets).each do |sheet|
        sheet.open do |f|
          IO.copy_stream(f, io)
        end
      end
    end

    def write_scss_variables(out, variables)
      out.puts "// BEGIN AUTO VARIABLES"
      out.puts scss_variable_assignments(variables)
      out.puts "// END AUTO VARIABLES"
    end

    def scss_variable_assignments(variables)
      variables.each_with_object("") do |(name, value), s|
        value = value.nil? ? "null" : value
        s << "$#{name}: #{value};\n"
      end
    end

    def variables
      {
        font:                   font,
        heading_font:           heading_font,
        heading_color:          heading_color,
        title:                  %Q("#{main.title}"),
        lslug:                  left_slug,
        rslug:                  right_slug,
        print_page_width:       print_page_width,
        print_page_height:      print_page_height,
        vector_cover_image:     "url(#{main.vector_cover_image})",
        cover_color:            cover_color,
      }
    end

    def template_files
      FileList[*@sheets.map(&:master_file)]
    end

    def source_files
      FileList[*@sheets.map(&:source_file)]
    end

    def master_files
      FileList[*@sheets.map(&:master_file)]
    end

    def template_for_source(source_file)
      @sheets.detect(NullStylesheet.method(:new)){
        |s| s.source_file == source_file
      }.template_file
    end

    def source_for_master(master_file)
      @sheets.detect(NullStylesheet.method(:new)){
        |s| s.master_file == master_file
      }.source_file
    end

    def var_file
      "#{main.build_dir}/vars.scss"
    end

    def source_dir
      "#{main.build_dir}/stylesheets"
    end

    def templates_dir
      File.expand_path("../../../templates/stylesheets", __FILE__)
    end

    def master_dir
      "#{main_master_dir}/stylesheets"
    end

    def main_master_dir
      main.master_dir
    end

    def sass_load_paths
      FileList[templates_dir]
    end
  end
end
