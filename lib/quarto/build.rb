# -*- coding: utf-8 -*-
require "rake"
require "nokogiri"
require "open3"
require "digest/sha1"
require "etc"
require "fattr"
require "time"
require "erb"
require "quarto/font"
require "quarto/stylesheet_set"
require "pathname"
require "ostruct"
require "yaml"

module Quarto

  # TODO: For the love of all that is holy, refactor me!!!
  class Build
    include Rake::DSL

    XINCLUDE_NS = "http://www.w3.org/2001/XInclude"
    XHTML_NS    = "http://www.w3.org/1999/xhtml"
    DC_NS       = "http://purl.org/dc/elements/1.1/"

    NAMESPACES = {
        "xhtml" => XHTML_NS,
        "xi"    => XINCLUDE_NS,
    }

    SIGNATURE_TEMPLATE = <<-EOF
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

    fattr :verbose => true
    fattr :metadata => true
    fattr(:authors) {
      [Etc.getpwnam(Etc.getlogin).gecos.split(',')[0]]
    }
    fattr :title => "Untitled Book"
    fattr(:name) { title.downcase.tr_s("^a-z0-9", "-") }
    fattr :description => ""
    fattr :language => "en"
    fattr(:date) { Time.now.iso8601 }
    fattr(:rights) {
      "Copyright © #{Time.parse(date).year} #{author}"
    }
    fattr(:extensions_to_source_formats) { {} }
    fattr(:plugins) { {} }
    fattr(:deliverable_files) { FileList[] }
    fattr(:extra_asset_files) { FileList[] }
    fattr(:all_master_files) {
      FileList[
          master_file,
          assets_file,
      ]
    }
    fattr(:fonts) { [] }
    fattr(:bitmap_cover_image) { nil }
    fattr(:vector_cover_image) { nil }
    fattr(:toplevel_classes) {
      %W[chapter] | nonchapter_classes
    }
    fattr(:frontmatter_classes) {
      %W[frontcover halftitlepage titlepage imprint dedication foreword
         toc preface]
    }
    fattr(:backmatter_classes) {
      %W[references appendix bibliography glossary index colophon backcover]
    }
    fattr(:nonchapter_classes) {
      frontmatter_classes | backmatter_classes
    }
    fattr(:build_dir) {
      "build"
    }
    fattr(:configured) { false }

    def initialize
      use :stylesheet_set
      yield self if block_given?
    end

    def use(plugin_name, *args, &block)
      plugin_class = find_plugin_class(plugin_name)
      plugin       = plugin_class.new(self, *args, &block)
      plugin.enhance_build(self)
      plugins[plugin_name.to_sym] = plugin
    end

    def find_plugin_class(plugin_name)
      require "quarto/#{plugin_name}"
      plugin_class_name =
          plugin_name.to_s.split("_").map { |w| w.capitalize }.join
      Quarto.const_get(plugin_class_name)
    end

    def add_font(family, options={})
      fonts << Font.new(family, options)
    end

    def define_tasks
      define_main_tasks
      define_plugin_tasks
    end

    def finalize
      plugins.values.each do |plugin|
        plugin.finalize_build(self)
      end
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

    def author
      authors.join(", ")
    end

    def source_exts
      extensions_to_source_formats.keys
    end

    def format_of_source_file(source_file)
      ext = source_file.pathmap("%x")[1..-1]
      extensions_to_source_formats.fetch(ext)
    end

    def source_files
      @source_files ||= FileList.new do |files|
        files.exclude(*source_exclusions)
      end
    end

    def export_dir
      "#{build_dir}/exports"
    end

    def export_files
      source_files.pathmap("#{export_dir}/%p").ext('.html')
    end

    def source_for_export_file(export_file)
      base    = export_file.sub(/^#{export_dir}\//, '').ext('')
      pattern = "#{base}.{#{source_exts.join(',')}}"
      FileList[pattern].first
    end

    def export(export_file, source_file)
      format = format_of_source_file(source_file)
      send("export_from_#{format}", export_file, source_file)
    end

    def signature_dir
      "#{build_dir}/signatures"
    end

    def signature_files
      export_files.pathmap("%{^#{export_dir},#{signature_dir}}X%{html,xhtml}x")
    end

    def export_for_signature_file(signature_file)
      signature_file.pathmap("%{^#{signature_dir},#{export_dir}}X%{xhtml,html}x")
    end

    def normalize_export(export_file, section_file, format)
      format ||= "NO_FORMAT_GIVEN"
      send("normalize_#{format}_export", export_file, section_file)
    end

    def normalize_generic_export(export_file, signature_file, before: nil)
      say("normalize #{export_file} to #{signature_file}")
      doc = open(export_file) do |f|
        Nokogiri::HTML(f)
      end

      before.call(doc) if before

      name            = export_file.pathmap("%n")
      title           = title_from_doc(doc)
      normal_doc      = Nokogiri::XML.parse(SIGNATURE_TEMPLATE)
      body_elt        = normal_doc.at_css("body")
      export_body_elt = doc.at_css("body")
      export_content  = export_body_elt && export_body_elt.xpath("section")
      if export_content.empty?
        chapter_contents = export_body_elt.children.dup
        export_content = manufacture_chapter(chapter_contents, normal_doc,
                                             title)
      end
      source_file   =
          FileList[export_file.pathmap("%{^#{export_dir}/,}X.*")].first
      signature_elt = body_elt.add_child(
          normal_doc.create_element("div") do |elt|
            elt["class"]                 = "signature"
            elt["data-signature-export"] = export_file
            elt["data-signature-source"] = source_file
            elt["data-signature-file"]   = signature_file
            elt["data-signature-name"]   = name
            elt["data-signature-title"]  = title
            elt["data-name"]             = name
            elt["data-title"]            = title
          end)

      signature_elt.add_child(export_content)
      normal_doc.at_css("title").content = title
      yield(normal_doc) if block_given?
      mark_toplevel_sections(normal_doc)
      extract_titles(normal_doc)
      open(signature_file, "w") do |f|
        format_xml(f) do |pipe_input|
          normal_doc.write_xml_to(pipe_input)
        end
      end
    end

    def manufacture_chapter(chapter_contents, doc, title)
      title = title == "Untitled Signature" ? "Untitled Chapter" : title
      doc.create_element("section",
                         "class"      => "chapter",
                         "data-title" => title,
                         "data-name"  => name_from_title(title)) do |elt|
        elt.children = chapter_contents
      end
    end

    def title_from_doc(doc)
      title_from_head(doc) || title_from_content(doc) || "Untitled Signature"
    end

    def title_from_head(doc)
      title_elt = doc.at_css("title")
      title     = title_elt && title_elt.text.strip
      unless title.nil? || title.empty?
        title
      end
    end

    def title_from_content(doc)
      headers      = doc.css("h1, h2, h3, h4, h5, h6")
      first_header = headers.first
      header_title = first_header && first_header.text.strip
      unless header_title.nil? || header_title.empty?
        header_title
      end
    end

    # At some point I stopped getting missing body elements for blank
    # markdown documents, and started getting a body element with a
    # single empty P tag instead. I'm not sure if this was a change in
    # Pandoc, a change in libxml2, or something else. I don't really
    # care either; this helper handles both the missing element and
    # the boilerplate cases.
    def body_has_meaningful_content?(body_elt)
      body_elt && body_elt.to_s != "<body><p></p></body>"
    end

    def mark_toplevel_sections(doc)
      selector = toplevel_classes.map { |c| "section[class~=#{c}]" }.join(",")
      doc.css(selector).each do |elt|
        elt["class"] = add_css_classes(elt, "toplevel")
      end
    end

    def add_css_classes(elt, *new_classes)
      (elt["class"].to_s.split + new_classes).join(" ")
    end

    def extract_titles(doc)
      doc.css("section.toplevel").each do |section_elt|
        type                      = toplevel_type_from_element(section_elt)
        first_heading             = section_elt.at_css("h1")
        title                     = title_from_element(first_heading, type)
        section_elt["data-title"] ||= title
        section_elt["data-name"]  ||= name_from_title(title)
      end
    end

    def title_from_element(element, type="item")
      title = element && element.text.strip
      if title.nil? || title.empty?
        title = "Untitled #{type.capitalize}"
      end
      title
    end

    def toplevel_type_from_element(element)
      (element["class"].split & toplevel_classes).first || "item"
    end

    def name_from_title(title)
      title.downcase.tr_s("^a-z0-9", " ").strip.tr(" ", "-")
    end

    def source_list_file
      "#{build_dir}/sources"
    end

    def spine_file
      "#{build_dir}/spine.xhtml"
    end

    def create_spine_file(spine_file, signature_files, options={})
      options = {
          stylesheets: stylesheets,
          metadata:    metadata
      }.merge(options)
      say("create #{spine_file} from sections: #{signature_files}")
      doc                              = Nokogiri::XML.parse(SPINE_TEMPLATE)
      doc.root.at_css("title").content = title
      add_metadata_to_doc(doc) if options[:metadata]
      doc.root.add_namespace("xi", "http://www.w3.org/2001/XInclude")
      head_elt    = doc.root.at_css("head")
      stylesheets = options[:stylesheets]
      stylesheets.each do |stylesheet|
        head_elt.add_child(stylesheet.link_tag)
      end
      signature_files.each do |section_file|
        doc.root["xml:base"] = ".."
        body                 = doc.root.at_css("body")
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
      add_metadata_element(doc, head_elt, "DC.rights", rights)
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
      "#{build_dir}/codex.xhtml"
    end

    def create_codex_file(codex_file, spine_file)
      mkdir_p(codex_file.pathmap("%d"))
      proto_codex_file = codex_file.pathmap("%d/proto-%f")
      expand_xinclude(proto_codex_file, spine_file, format: false)
      proto_doc = Nokogiri::XML(File.read(proto_codex_file))
      update_signature_elements(proto_doc)
      update_toplevel_elements(proto_doc)
      update_heading_elements(proto_doc)
      open(codex_file, "w") do |f|
        proto_doc.write_xml_to(f)
      end

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
        classes = pre_elt["class"].split
        classes.delete("sourceCode")
        unless classes.size == 1
          raise "Ambiguous source code language in classes: #{classes}"
        end
        lang         = classes.first
        ext          = {"ruby" => "rb"}.fetch(lang) { lang.downcase }
        code         = strip_listing(pre_elt.at_css("code").text)
        digest       = Digest::SHA1.hexdigest(code)
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
        inc_elt        = skel_doc.create_element("xi:include") do |elt|
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
      doc.xpath("//xi:include", NAMESPACES).map { |e| e["href"] }
    end

    def listing_for_highlight_file(highlight_file)
      base = highlight_file.pathmap("%n")
      FileList["#{listings_dir}/#{base}.*"].first
    end

    # Strip extraneous whitespace from around a code listing
    def strip_listing(code)
      code = code.dup
      code.gsub!(/\t/, "  ")
      lines           = code.split("\n")
      first_code_line = lines.index { |l| l =~ /\S/ }
      last_code_line  = lines.rindex { |l| l =~ /\S/ }
      code_lines      = lines[first_code_line..last_code_line]
      line_indents    = code_lines.map { |l| l.index(/\S/) || 0 }
      min_indent      = line_indents.min
      unindented_code = code_lines.map { |l| l[min_indent..-1] }.join("\n")
      unindented_code.strip
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

    def update_signature_elements(doc)
      doc.css(".signature").each_with_index do |signature_elt, index|
        name = signature_elt["data-signature-name"] or
            fail "Missing signature name"
        number = index + 1

        signature_elt["data-signature-number"] = number
        signature_elt["data-number"]           = number
        signature_elt["id"]                    = "signature-#{number}"
        signature_elt["data-fascicle"]         = fascicle_file(name, number)
      end
    end

    def update_toplevel_elements(doc)
      doc.css(".signature").each do |sig_elt|
        fasc_file = sig_elt["data-fascicle"]
        sig_num = sig_elt["data-number"] or fail "Signature is not numbered"
        sig_elt.css("section.toplevel").each_with_index do |top_elt, index|
          number                   = index + 1
          type                     = toplevel_type_from_element(top_elt)
          top_elt["id"]            = "signature-#{sig_num}-#{type}-#{index}"
          top_elt["data-number"]   = number
          top_elt["data-fascicle"] = fasc_file
        end
      end
    end

    def update_heading_elements(doc)
      replacements = {}
      doc.css("section.toplevel").each do |top_elt|
        top_num = top_elt["data-number"] or fail "Element is not numbered"
        top_id = top_elt["id"] or fail "Element is missing ID"
        top_elt.css("h1, h2, h3, h4, h5, h6").each_with_index do
        |heading_elt, index|
          old_id               = heading_elt["id"]
          new_id               = top_id + "-heading-#{index + 1}"
          heading_elt["id"]    = new_id
          replacements[old_id] = new_id
        end
      end
      doc.css("a[href^='#']").each do |link_elt|
        target_id = link_elt["href"][1..-1]
        if (new_id = replacements[target_id])
          link_elt["href"] = "##{new_id}"
        end
      end
    end

    def fascicle_manifest
      "#{build_dir}/fascicle-manifest.txt"
    end

    def fascicle_dir
      "#{build_dir}/fascicles"
    end

    def extract_fascicles(master_file, fascicle_manifest)
      master_doc = open(master_file) do |f|
        Nokogiri::XML(f)
      end
      fasc_elts  = master_doc.css(".signature")
      paths      = []
      fasc_elts.each_with_index { |elt, index|
        name     = elt["data-signature-name"]
        number   = index + 1
        path     = fascicle_file(name, number)
        title    = elt["data-signature-title"]
        fasc_doc = master_doc.dup

        fasc_doc.at_css("body").children = elt.dup
        fasc_doc.at_css("title").content = title
        mkpath path.pathmap("%d")
        open(path, "w") do |f|
          format_xml(f) do |format_input|
            say "write #{path}"
            fasc_doc.write_xml_to(format_input)
          end
        end
        paths << path
      }
      say "write #{fascicle_manifest}"
      open(fascicle_manifest, "w") do |f|
        paths.each do |path|
          f.puts(path)
        end
      end
    end

    def fascicle_file(name, number)
      filename = "%03d-%s.xhtml" % [number, name]
      "#{fascicle_dir}/#{filename}"
    end

    def fascicles
      File.read(fascicle_manifest).split.map.with_index { |path, index|
        doc    = open(path) { |f| Nokogiri::XML(f) }
        name   = doc.at_css(".signature")["data-signature-name"]
        number = index + 1
        OpenStruct.new(
            path:          path,
            title:         doc.at_css("title").text.strip,
            name:          name,
            number:        number,
            numbered_name: "%03d-%s" % [number, name])
      }
    end

    def assets_file
      "#{build_dir}/assets.timestamp"
    end

    def copy_assets(master_file, assets_dir)
      asset_files = []
      if bitmap_cover_image
        asset_files << bitmap_cover_image
      end
      if vector_cover_image
        asset_files << vector_cover_image
      end
      asset_files.concat(extra_asset_files)
      doc        = open(master_file) do |f|
        Nokogiri::XML(f)
      end
      asset_elts = doc.css("*[src]")
      asset_elts.each do |elt|
        asset_path = Pathname(elt["src"]).cleanpath
        asset_files << asset_path
      end
      asset_files.each do |asset_path|
        rel_path = Pathname(asset_path).relative_path_from(Pathname("."))
        dest     = Pathname(assets_dir) + rel_path
        mkdir_p dest.dirname unless dest.dirname.exist?
        ln_sf Pathname(asset_path).relative_path_from(dest.dirname), dest
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

    def say(*messages)
      $stderr.puts(*messages) if verbose
    end

    # Require a plugin to be loaded and added. This is mainly for the use of
    # other plugins. If you want to add a plugin to your project,
    # invoke{#use} directly.
    def require_plugin(plugin_name)
      return if plugins.key?(plugin_name.to_sym)
      plugin_class = find_plugin_class(plugin_name)
      use(plugin_name)
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

    def structure_file
      "#{build_dir}/structure.yaml"
    end

    def generate_structure_file(file)
      File.write(file, YAML.dump({book: {children: []}}))
    end

    def define_main_tasks
      task :default => :deliverables

      desc "Export from source formats to HTML"
      task :export => [*export_files]

      desc "Generate normalized XHTML versions of exports"
      task :signatures => [*signature_files]

      desc "Build a single XHTML file codex combining all signatures"
      task :codex => codex_file

      desc "Strip out code listings for highlighting"
      task :skeleton => skeleton_file

      desc "Create master file suitable for conversion into deliverable formats"
      task :master => [master_file, assets_file]

      desc "Create finished documents suitable for end-users"
      task :deliverables => deliverable_files

      desc "Perform source-code highlighting"
      task :highlight => highlights_file

      desc "Separate master into smaller chunks"
      task :fascicles => fascicle_manifest

      desc "Build complete representaiton of the book structure"
      task :structure => structure_file

      file structure_file => ["fascicles"] do
        generate_structure_file(structure_file)
      end

      file fascicle_manifest => master_file do
        extract_fascicles(master_file, fascicle_manifest)
      end

      file highlights_file => [skeleton_file] do |t|
        highlights_needed  = highlights_needed_by(skeleton_file)
        missing_highlights = highlights_needed - FileList["#{highlights_dir}/*.html"]
        sub_task           = Rake::MultiTask.new("highlight_dynamic", Rake.application)
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

      signature_files.each do |section_file|
        file section_file => export_for_signature_file(section_file) do |t|
          export_file   = export_for_signature_file(section_file)
          source_file   = source_for_export_file(export_file)
          source_format = format_of_source_file(source_file)
          mkdir_p section_file.pathmap("%d")
          normalize_export(export_file, section_file, source_format)
        end
      end

      file spine_file => [build_dir, *signature_files] do |t|
        create_spine_file(t.name, signature_files, stylesheets: stylesheets)
      end

      file codex_file => [spine_file, *signature_files] do |t|
        create_codex_file(t.name, spine_file)
      end

      directory listings_dir

      file skeleton_file => [codex_file, listings_dir] do |t|
        create_skeleton_file(t.name, codex_file)
      end

      rule /^#{highlights_dir}\/[[:xdigit:]]+\.html$/ =>
               [->(highlight_file) { listing_for_highlight_file(highlight_file) }] do |t|
        dir = t.name.pathmap("%d")
        mkdir_p dir unless File.exist?(dir)
        sh "pygmentize -o #{t.name} -f html #{t.source}"
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
