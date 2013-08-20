require 'rake'
require 'nokogiri'
require 'open3'
require 'digest/sha1'
require 'etc'
require 'fattr'
require 'time'
require 'erb'

module Quarto
  class Build
    include Rake::DSL

    XINCLUDE_NS = "http://www.w3.org/2001/XInclude"
    XHTML_NS    = "http://www.w3.org/1999/xhtml"

    NAMESPACES = {
      "xhtml" => XHTML_NS,
      "xi"    => XINCLUDE_NS,
    }

    SECTION_TEMPLATE = <<-EOF
  <!DOCTYPE html>
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title></title>
    </head>
    <body>
    </body>
  </html>
  EOF

    SPINE_TEMPLATE = <<-EOF
  <!DOCTYPE html>
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Untitled Book</title>
      <link rel="schema.DC" href="http://purl.org/dc/elements/1.1/"/>
    </head>
    <body>
    </body>
  </html>
  EOF

    fattr :verbose              => true
    fattr :metadata             => true
    fattr(:authors) {
      [Etc.getpwnam(Etc.getlogin).gecos.split(',')[0]]
    }
    fattr :title                => "Untitled Book"
    fattr :description          => ""
    fattr :language             => ENV["LANG"].to_s.split(".").first
    fattr(:date)                { Time.now.iso8601 }
    fattr(:stylesheets)         { FileList[base_stylesheet, code_stylesheet] }
    fattr(:extensions_to_source_formats) { {} }
    fattr(:plugins)             { {} }
    fattr(:deliverable_files)   { FileList[latex_file] }
    fattr(:extra_asset_files)   { FileList[] }
    fattr(:font)                { 'serif' }
    fattr(:heading_font)        { '"PT Sans", sans-serif' }
    fattr(:heading_color)       { "black" }
    fattr(:left_slug)           { nil }
    fattr(:right_slug)          { nil }
    fattr(:print_page_width)    { "7.5in" }
    fattr(:print_page_height)   { "9in"   }
    fattr(:bitmap_cover_image)  { nil }
    fattr(:vector_cover_image)  { nil }
    fattr(:cover_color)         { "black" }

    def initialize
      yield self if block_given?
    end

    def use(plugin_name, *args, &block)
      require "quarto/#{plugin_name}"
      plugin_class_name = plugin_name.to_s.split("_").map{|w| w.capitalize}.join
      plugin_class = Quarto.const_get(plugin_class_name)
      plugin = plugin_class.new(self, *args, &block)
      plugin.enhance_build(self)
      plugins[plugin_name.to_sym] = plugin
    end

    def define_tasks
      define_main_tasks
      define_plugin_tasks
    end

    def source_exclusions
      @source_exclusions ||= ["#{build_dir}/**/*"]
    end

    def exclude_sources(*exclusion_patterns)
      source_files.exclude(*exclusion_patterns)
    end

    def source_files=(new_source_files)
      @source_files = Rake::FileList[*new_source_files]
    end

    def author=(sole_author)
      self.authors = [sole_author]
    end

    def build_dir
      "build"
    end

    def source_exts
      extensions_to_source_formats.keys
    end

    def format_of_source_file(source_file)
      ext = source_file.pathmap("%x")[1..-1]
      extensions_to_source_formats.fetch(ext)
    end

    def source_files
      @source_files ||= FileList.new("**/*.{#{source_exts.join(',')}}") do |files|
        files.exclude(*source_exclusions)
      end
    end

    def export_dir
      "build/exports"
    end

    def export_files
      source_files.pathmap("#{export_dir}/%p").ext('.html')
    end

    def source_for_export_file(export_file)
      base = export_file.sub(/^#{export_dir}\//,'').ext('')
      pattern = "#{base}.{#{source_exts.join(',')}}"
      FileList[pattern].first
    end

    def export(export_file, source_file)
      format = format_of_source_file(source_file)
      send("export_from_#{format}", export_file, source_file)
    end

    def section_dir
      "build/sections"
    end

    def section_files
      export_files.pathmap("%{^#{export_dir},#{section_dir}}X%{html,xhtml}x")
    end

    def export_for_section_file(section_file)
      section_file.pathmap("%{^#{section_dir},#{export_dir}}X%{xhtml,html}x")
    end

    def normalize_export(export_file, section_file, format)
      format ||= "NO_FORMAT_GIVEN"
      send("normalize_#{format}_export", export_file, section_file)
    end

    def normalize_generic_export(export_file, section_file)
      say("normalize #{export_file} to #{section_file}")
      doc = open(export_file) do |f|
        Nokogiri::HTML(f)
      end
      normal_doc = Nokogiri::XML.parse(SECTION_TEMPLATE)
      body_elt        = normal_doc.at_css("body")
      export_body_elt = doc.at_css("body")
      if export_body_elt
        body_elt.replace(export_body_elt)
      else
        body_elt.add_child(
          normal_doc.create_comment("No content for #{export_file}"))
      end
      normal_doc.at_css("title").content = export_file.pathmap("%n")
      yield(normal_doc) if block_given?
      open(section_file, "w") do |f|
        format_xml(f) do |pipe_input|
          normal_doc.write_xml_to(pipe_input)
        end
      end
    end

    def source_list_file
      "build/sources"
    end

    def code_stylesheet
      "#{build_dir}/code.css"
    end

    def base_stylesheet
      "#{build_dir}/base.css"
    end

    def base_stylesheet_scss
      "#{build_dir}/base.scss"
    end

    def base_stylesheet_template
      File.expand_path("../../../templates/base.scss", __FILE__)
    end

    def spine_file
      "build/spine.xhtml"
    end

    def create_spine_file(spine_file, section_files, options={})
      options = {
        stylesheets: stylesheets,
        metadata:    metadata
      }.merge(options)
      say("create #{spine_file}")
      doc = Nokogiri::XML.parse(SPINE_TEMPLATE)
      doc.root.at_css("title").content = title
      add_metadata_to_doc(doc) if options[:metadata]
      doc.root.add_namespace("xi", "http://www.w3.org/2001/XInclude")
      head_elt = doc.root.at_css("head")
      stylesheets = Array(options[:stylesheets])
      stylesheets.each do |stylesheet|
        head_elt.add_child(
          doc.create_element(
            "style",
            File.read(stylesheet)))
      end
      section_files.each do |section_file|
        doc.root["xml:base"] = ".."
        body = doc.root.at_css("body")
        body.add_child(doc.create_element("xi:include") do |inc_elt|
            inc_elt["href"]     = section_file
            inc_elt["xpointer"] = "xmlns(ns=http://www.w3.org/1999/xhtml)xpointer(//ns:body/*)"
            inc_elt.add_child(doc.create_element("xi:fallback") do |fallback_elt|
                fallback_elt.add_child(doc.create_element("p",
                    "[Missing section: #{section_file}]"))
              end)
          end)
      end
      open(spine_file, 'w') do |f|
        format_xml(f) do |format_input|
          doc.write_to(format_input)
        end
      end
    end

    def add_metadata_to_doc(doc)
      head_elt = doc.at_css("head")
      add_metadata_element(doc, head_elt, "author", authors.join(", "))
      add_metadata_element(doc, head_elt, "date", date)
      add_metadata_element(doc, head_elt, "subject", description)
      add_metadata_element(doc, head_elt, "generator", "Quarto #{Quarto::VERSION}")
      add_metadata_element(doc, head_elt, "DC.title", title)
      add_metadata_element(doc, head_elt, "DC.creator", authors)
      add_metadata_element(
        doc, head_elt, "DC.description", description)
      add_metadata_element(doc, head_elt, "DC.date", date)
      add_metadata_element(doc, head_elt, "DC.language", language)
    end

    def add_metadata_element(doc, parent, name, value)
      Array(value).each do |value|
        parent.add_child(doc.create_element("meta") do |meta|
            meta["name"]    = name
            meta["content"] = value
          end)
      end
    end

    def codex_file
      "build/codex.xhtml"
    end

    def create_codex_file(codex_file, spine_file)
      expand_xinclude(codex_file, spine_file)
    end

    def skeleton_file
      "#{build_dir}/skeleton.xhtml"
    end

    def listings_dir
      "#{build_dir}/listings"
    end

    def create_skeleton_file(skeleton_file, codex_file)
      say("scan #{codex_file} for source code listings")
      skel_doc = open(codex_file) do |f|
        Nokogiri::XML(f)
      end
      skel_doc.css("pre.sourceCode").each_with_index do |pre_elt, i|
        lang = pre_elt["class"].split[1]
        ext  = {"ruby" => "rb"}.fetch(lang){ lang.downcase }
        code     = strip_listing(pre_elt.at_css("code").text)
        digest   = Digest::SHA1.hexdigest(code)
        listing_path = "#{listings_dir}/#{digest}.#{ext}"
        if File.exist?(listing_path)
          say "skip extant listing #{listing_path}"
        else
          say("extract listing #{i} to #{listing_path}")
          open(listing_path, 'w') do |f|
            f.write(code)
          end
        end
        highlight_path = "#{highlights_dir}/#{digest}.html"
        inc_elt = skel_doc.create_element("xi:include") do |elt|
          elt["href"] = highlight_path
          elt.add_child(
            "<xi:fallback>"\
            "<p>[Missing code listing: #{highlight_path}]</p>"\
            "</xi:fallback>")
        end
        pre_elt.replace(inc_elt)
      end
      say("create #{skeleton_file}")
      open(skeleton_file, "w") do |f|
        format_xml(f) do |format_input|
          skel_doc.write_xml_to(format_input)
        end
      end
    end

    def highlights_file
      "#{build_dir}/highlights.timestamp"
    end

    def highlights_dir
      "#{build_dir}/highlights"
    end

    def highlights_needed_by(skeleton_file)
      doc = open(skeleton_file) do |f|
        Nokogiri::XML(f)
      end
      doc.xpath("//xi:include", NAMESPACES).map{|e| e["href"]}
    end

    def listing_for_highlight_file(highlight_file)
      base = highlight_file.pathmap("%n")
      FileList["#{listings_dir}/#{base}.*"].first
    end

    # Strip extraneous whitespace from around a code listing
    def strip_listing(code)
      code = code.dup
      code.strip!
      code.gsub!(/\t/, "  ")
      lines  = code.split("\n")
      first_code_line = lines.index{|l| l =~ /\S/}
      last_code_line  = lines.rindex{|l| l =~ /\S/}
      lines = lines[first_code_line..last_code_line]
      indent = lines.map{|l| l.index(/[^ ]/) || 0}.min
      lines.map{|l| l[indent..-1]}.join("\n")
    end

    def master_file
      "#{master_dir}/master.xhtml"
    end

    def master_dir
      "#{build_dir}/master"
    end

    def create_master_file(master_file, skeleton_file)
      mkdir_p(master_file.pathmap("%d"))
      expand_xinclude(master_file, skeleton_file, format: false)
    end

    def assets_file
      "#{build_dir}/assets.timestamp"
    end

    def copy_assets(master_file, assets_dir)
      asset_files = []
      asset_files.concat(extra_asset_files)
      doc = open(master_file) do |f|
        Nokogiri::XML(f)
      end
      asset_elts = doc.css("*[src]")
      asset_elts.each do |elt|
        asset_path = Pathname(elt["src"]).cleanpath
        asset_files << asset_path
      end
      asset_files.each do |asset_path|
        rel_path   = asset_path.relative_path_from(Pathname("."))
        dest       = Pathname(assets_dir) + rel_path
        mkdir_p dest.dirname
        ln_sf asset_path.relative_path_from(dest.dirname), dest
      end
    end

    def deliverable_dir
      "#{build_dir}/deliverables"
    end

    def latex_file
      "#{deliverable_dir}/book.latex"
    end

    def pandoc
      "pandoc"
    end

    def pandoc_vars
      [
        "-Vtitle=#{title}",
        "-Vauthor=#{authors.join(', ')}",
        "-Vdate=#{date}",
        "-Vlang=#{language}"
      ]
    end

    def vendor_dir
      "#{quarto_dir}/vendor"
    end

    def quarto_dir
      ".quarto"
    end

    def expand_template(template_file, output_file)
      say "expand #{template_file} to #{output_file}"
      File.write(output_file, ERB.new(File.read(template_file)).result(binding))
    end

    private

    def format_xml(output_io)
      Open3.popen2(*xmllint_command(*%W[--format --xmlout -])) do
        |stdin, stdout, wait_thr|
        yield(stdin)
        stdin.close
        IO.copy_stream(stdout, output_io)
      end
    end

    def expand_xinclude(output_file, input_file, options={})
      options = {format: true}.merge(options)
      say("expand #{input_file} to #{output_file}")
      cleanup_args = %W[--nsclean --xmlout --nofixup-base-uris]
      if options[:format]
        cleanup_args << "--format"
      end
      Open3.pipeline_r(
        xmllint_command(*%W[--nofixup-base-uris --xinclude --xmlout #{input_file}]),
        # In order to clean up extraneous namespace declarations we need a second
        # xmllint process
        xmllint_command(*cleanup_args, "-")) do |output, wait_thr|
        open(output_file, 'w') do |f|
          IO.copy_stream(output, f)
        end
      end
    end

    def say(*messages)
      $stderr.puts(*messages) if verbose
    end

    def xmlflags
      if verbose
        []
      else
        ["--nowarning"]
      end
    end

    def xmllint_command(*args)
      ["xmllint", *xmlflags, *args]
    end

    def add_scss_variables(source_file, output_file, variables)
      open(output_file, 'w') do |out|
        out.puts "// BEGIN AUTO VARIABLES"
        out.puts scss_variable_assignments(variables)
        out.puts "// END AUTO VARIABLES"
        open(source_file) do |source|
          IO.copy_stream(source, out)
        end
      end
    end

    def scss_variable_assignments(variables)
      variables.each_with_object("") do |(name, value), s|
        value = value.nil? ? "null" : value
        s << "$#{name}: #{value};\n"
      end
    end

    def stylesheet_variables
      {
        font: font,
        heading_font: heading_font,
        heading_color: heading_color,
        title: %Q("#{title}"),
        lslug: left_slug,
        rslug: right_slug,
        print_page_width: print_page_width,
        print_page_height: print_page_height,
        vector_cover_image: "url(#{vector_cover_image})",
        cover_color: cover_color,
      }
    end

    def define_main_tasks
      task :default => :deliverables

      desc "Export from source formats to HTML"
      task :export => [*export_files]

      desc "Generate normalized XHTML versions of exports"
      task :sections => [*section_files]

      desc "Build a single XHTML file codex combining all sections"
      task :codex => codex_file

      desc "Strip out code listings for highlighting"
      task :skeleton => skeleton_file

      desc "Create master file suitable for conversion into deliverable formats"
      task :master => [master_file, assets_file]

      desc "Create finished documents suitable for end-users"
      task :deliverables => deliverable_files

      desc "Perform source-code highlighting"
      task :highlight => highlights_file

      file highlights_file => [skeleton_file] do |t|
        highlights_needed  = highlights_needed_by(skeleton_file)
        missing_highlights = highlights_needed - FileList["#{highlights_dir}/*.html"]
        sub_task = Rake::MultiTask.new("highlight_dynamic", Rake.application)
        sub_task.enhance(missing_highlights.compact)
        sub_task.invoke
        touch highlights_file
      end

      directory build_dir
      directory export_dir => [build_dir]
      directory deliverable_dir => build_dir

      export_files.each do |export_file|
        file export_file =>
          [export_dir, source_for_export_file(export_file)] do |t|
          source_file = source_for_export_file(export_file)
          mkdir_p export_file.pathmap("%d")
          export(export_file, source_file)
        end
      end

      section_files.each do |section_file|
        file section_file => export_for_section_file(section_file) do |t|
          export_file   = export_for_section_file(section_file)
          source_file   = source_for_export_file(export_file)
          source_format = format_of_source_file(source_file)
          mkdir_p section_file.pathmap("%d")
          normalize_export(export_file, section_file, source_format)
        end
      end

      file code_stylesheet do |t|
        sh "pygmentize -S colorful -f html > #{t.name}"
      end

      file base_stylesheet => base_stylesheet_scss do |t|
        sh *%W[sass --scss #{base_stylesheet_scss} #{t.name}]
      end

      file base_stylesheet_scss => base_stylesheet_template do |t|
        add_scss_variables(
          base_stylesheet_template,
          t.name,
          stylesheet_variables)
      end

      file spine_file => [build_dir, *stylesheets] do |t|
        create_spine_file(t.name, section_files, stylesheets: stylesheets)
      end

      file codex_file => [spine_file, *section_files] do |t|
        create_codex_file(t.name, spine_file)
      end

      directory listings_dir

      file skeleton_file => [codex_file, listings_dir] do |t|
        create_skeleton_file(t.name, codex_file)
      end

      rule /^#{highlights_dir}\/[[:xdigit:]]+\.html$/ =>
        [->(highlight_file){listing_for_highlight_file(highlight_file)}] do |t|
        dir = t.name.pathmap("%d")
        mkdir_p dir unless File.exist?(dir)
        sh *%W[pygmentize -o #{t.name} #{t.source}]
      end

      file master_file => [skeleton_file, highlights_file] do |t|
        create_master_file(t.name, skeleton_file)
      end

      file latex_file => [master_file, assets_file] do |t|
        mkdir_p t.name.pathmap("%d")
        sh pandoc, *pandoc_vars, *%W[--standalone -o #{t.name} #{master_file}]
      end

      directory vendor_dir

      file assets_file => master_file do |t|
        copy_assets(master_file, master_dir)
        touch t.name
      end
    end

    def define_plugin_tasks
      plugins.values.each do |plugin|
        plugin.define_tasks
      end
    end
  end
end
