require "quarto/version"
require 'rake'
require 'nokogiri'
require 'open3'
require 'digest/sha1'
require 'etc'
require 'fattr'
require 'time'
require 'erb'

module Quarto
  include Rake::DSL

  XINCLUDE_NS = "http://www.w3.org/2001/XInclude"
  XHTML_NS    = "http://www.w3.org/1999/xhtml"

  EXTENSIONS_TO_SOURCE_FORMATS = {
    "md"       => "markdown",
    "markdown" => "markdown",
    "org"      => "orgmode"
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

  ORG_EXPORT_ASYNC     = "nil"
  ORG_EXPORT_SUBTREE   = "nil"
  ORG_EXPORT_VISIBLE   = "nil"
  ORG_EXPORT_BODY_ONLY = "t"
  ORG_EXPORT_ELISP     = <<END
(progn
  (setq org-html-htmlize-output-type 'css)
  (org-mode)
  (message (concat "Org version: " org-version))
  (cd "<%= export_dir %>")
  (org-html-export-to-html
    <%= ORG_EXPORT_ASYNC %> <%= ORG_EXPORT_SUBTREE %>
    <%= ORG_EXPORT_VISIBLE %> <%= ORG_EXPORT_BODY_ONLY %>
    (quote (<%= orgmode_export_plist %>)))
  (kill-emacs))
END

  Fattr :metadata    => true
  Fattr(:authors) {
    [Etc.getpwnam(Etc.getlogin).gecos.split(',')[0]]
  }
  Fattr :title       => "Untitled Book"
  Fattr :description => ""
  Fattr :language    => ENV["LANG"].to_s.split(".").first
  Fattr(:date) {        Time.now.iso8601 }
  Fattr :git         => true
  Fattr(:emacs_load_path) {
    FileList[orgmode_lisp_dir]
  }

  def self.configure
    yield self
  end

  def self.configuration
    Quarto
  end

  def self.stylesheets
    @stylesheets ||= [code_stylesheet]
  end

  def self.source_exclusions
    @source_exclusions ||= ["#{build_dir}/*", ".git/*"]
  end

  def self.exclude_source(exclude_glob)
    source_exclusions << exclude_glob
  end

  def self.source_files=(new_source_files)
    @source_files = Rake::FileList[*new_source_files]
  end

  def self.author=(sole_author)
    self.authors = [sole_author]
  end

  def self.reset
    @stylesheets       = nil
    @source_exclusions = nil
  end

  def configuration
    Quarto
  end

  def source_files
    configuration.source_files
  end

  module_function


  def build_dir
    "build"
  end

  def source_exts
    EXTENSIONS_TO_SOURCE_FORMATS.keys
  end

  def format_of_source_file(source_file)
    ext = source_file.pathmap("%x")[1..-1]
    EXTENSIONS_TO_SOURCE_FORMATS.fetch(ext)
  end

  def self.source_files
    @source_files ||= FileList.new("**/*.{#{source_exts.join(',')}}") do |files|
      configuration.source_exclusions.each do |exclusion|
        files.exclude(exclusion)
        files.exclude do |file|
          next false unless configuration.git?
          # First check that this is a git repo
          next false unless system("git status -s > /dev/null 2>&1")
          # See if it is a registered file with git
          ls_git = `git ls-files #{file}`
          # See if it is an unregistered but un-ignored file
          ls_other =
            `git ls-files --others --exclude-per-directory .gitignore #{file}`
          # If it shows up in neither of the above, exclude it
          ls_git.empty? && ls_other.empty?
        end
      end
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

  def export_from_markdown(export_file, source_file)
    sh *%W[pandoc --no-highlight -w html5 -o #{export_file} #{source_file}]
  end

  def export_from_orgmode(export_file, source_file)
    language = configuration.language
    elisp = ERB.new(ORG_EXPORT_ELISP).result(binding)
    sh "emacs", *emacs_flags, *%W[--file #{source_file} --eval #{elisp}]
  end

  def emacs_flags
    emacs_load_path_flags = configuration.emacs_load_path.pathmap("--directory=%p")
    ["--batch", *emacs_load_path_flags]
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

  def normalize_markdown_export(export_file, section_file)
    normalize_generic_export(export_file, section_file)
  end

  def normalize_generic_export(export_file, section_file)
    puts "normalize #{export_file} to #{section_file}"
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

  def normalize_orgmode_export(export_file, section_file)
    normalize_generic_export(export_file, section_file) do |normal_doc|
      listing_pre_elts = normal_doc.css("div.org-src-container > pre.src")
      listing_pre_elts.each do |elt|
        language = elt["class"].split.grep(/^src-(.*)$/) do
          break $1
        end
        elt.parent.replace(normal_doc.create_element("pre") do |pre_elt|
            pre_elt["class"] = "sourceCode #{language}"
            pre_elt.add_child(normal_doc.create_element("code", elt.text))
          end)
      end
      figure_elts = normal_doc.css("div.figure")
      figure_elts.each do |elt|
        img_elt = elt.css("img")
        caption = elt.at_css("p:nth-child(2)").content
        elt.replace(normal_doc.create_element("figure") do |fig_elt|
            fig_elt.add_child(img_elt)
            fig_elt.add_child(normal_doc.create_element("figcaption", caption))
          end)
      end
    end
  end

  def source_list_file
    "build/sources"
  end

  def code_stylesheet
    "#{build_dir}/code.css"
  end

  def spine_file
    "build/spine.xhtml"
  end

  def create_spine_file(spine_file, section_files, options={})
    options = {
      stylesheets: configuration.stylesheets,
      metadata:    configuration.metadata
    }.merge(options)
    puts "create #{spine_file}"
    doc = Nokogiri::XML.parse(SPINE_TEMPLATE)
    doc.root.at_css("title").content = configuration.title
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
    add_metadata_element(doc, head_elt, "author", configuration.authors.join(", "))
    add_metadata_element(doc, head_elt, "date", configuration.date)
    add_metadata_element(doc, head_elt, "subject", configuration.description)
    add_metadata_element(doc, head_elt, "generator", "Quarto #{Quarto::VERSION}")
    add_metadata_element(doc, head_elt, "DC.title", configuration.title)
    add_metadata_element(doc, head_elt, "DC.creator", configuration.authors)
    add_metadata_element(
      doc, head_elt, "DC.description", configuration.description)
    add_metadata_element(doc, head_elt, "DC.date", configuration.date)
    add_metadata_element(doc, head_elt, "DC.language", configuration.language)
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
    puts "scan #{codex_file} for source code listings"
    skel_doc = open(codex_file) do |f|
      Nokogiri::XML(f)
    end
    skel_doc.css("pre.sourceCode").each_with_index do |pre_elt, i|
      lang = pre_elt["class"].split[1]
      ext  = {"ruby" => "rb"}.fetch(lang){ lang.downcase }
      code     = pre_elt.at_css("code").text
      digest   = Digest::SHA1.hexdigest(code)
      listing_path = "#{listings_dir}/#{digest}.#{ext}"
      puts "extract listing #{i} to #{listing_path}"
      open(listing_path, 'w') do |f|
        f.write(strip_listing(code))
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
    puts "create #{skeleton_file}"
    open(skeleton_file, "w") do |f|
      format_xml(f) do |format_input|
        skel_doc.write_xml_to(format_input)
      end
    end
  end

  def highlights_dir
    "#{build_dir}/highlights"
  end

  def highlights_needed_by(skeleton_file)
    doc = open(skeleton_file) do |f|
      Nokogiri::XML(f)
    end
    doc.xpath("//xi:include", "xi" => XINCLUDE_NS).map{|e| e["href"]}
  end

  def listing_for_highlight_file(highlight_file)
    base = highlight_file.pathmap("%n")
    FileList["#{listings_dir}/#{base}.*"].first
  end

  # Strip extraneous whitespace from around a code listing
  def strip_listing(code)
    code.gsub!(/\t/, "  ")
    lines  = code.split("\n")
    first_code_line = lines.index{|l| l =~ /\S/}
    last_code_line  = lines.rindex{|l| l =~ /\S/}
    lines = lines[first_code_line..last_code_line]
    indent = lines.map{|l| l.index(/[^ ]/) || 0}.min
    lines.map{|l| l.slice(indent..-1)}.join("\n") + "\n"
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
    doc = open(master_file) do |f|
      Nokogiri::XML(f)
    end
    asset_elts = doc.css("*[src]")
    asset_elts.each do |elt|
      asset_path = Pathname(elt["src"]).cleanpath
      rel_path   = asset_path.relative_path_from(Pathname("."))
      dest       = Pathname(assets_dir) + rel_path
      mkdir_p dest.dirname
      ln_sf asset_path.relative_path_from(dest.dirname), dest
    end
  end

  def deliverable_dir
    "#{build_dir}/deliverables"
  end

  def deliverable_files
    [pdf_file, latex_file]
  end

  def pdf_file
    "#{deliverable_dir}/book.pdf"
  end

  def latex_file
    "#{deliverable_dir}/book.latex"
  end

  def pandoc_vars
    [
      "-Vtitle=#{configuration.title}",
      "-Vauthor=#{configuration.authors.join(', ')}",
      "-Vdate=#{configuration.date}",
      "-Vlang=#{configuration.language}"
    ]
  end

  def orgmode_version
    "8.0.7"
  end

  def orgmode_lisp_dir
    "#{vendor_orgmode_dir}/lisp"
  end

  def orgmode_export_plist
    %W[
      :with-toc             nil
      :headline-levels      6
      :section-numbers      nil
      :language             #{configuration.language}
      :htmlized-source      nil
      :html-postamble       nil
      :with-sub-superscript nil
    ].join(" ")
  end

  def vendor_orgmode_dir
    "#{vendor_dir}/org-#{orgmode_version}"
  end

  def vendor_dir
    "#{quarto_dir}/vendor"
  end

  def quarto_dir
    ".quarto"
  end

  private

  def format_xml(output_io)
    Open3.popen2(*%W[xmllint --format --xmlout -]) do
      |stdin, stdout, wait_thr|
      yield(stdin)
      stdin.close
      IO.copy_stream(stdout, output_io)
    end
  end

  def expand_xinclude(output_file, input_file, options={})
    options = {format: true}.merge(options)
    puts "expand #{input_file} to #{output_file}"
    cleanup_args = %W[--nsclean --xmlout --nofixup-base-uris]
    if options[:format]
      cleanup_args << "--format"
    end
    Open3.pipeline_r(
      %W[xmllint --nofixup-base-uris --xinclude --xmlout #{input_file}],
      # In order to clean up extraneous namespace declarations we need a second
      # xmllint process
      ["xmllint",  *cleanup_args, "-"]) do |output, wait_thr|
      # doc = Nokogiri::XML(output)
      # doc.xpath("//xhtml:body//*[@xml:base]", "xhtml" => XHTML_NS).each do |elt|
      #   puts "!!! Removing xml:base #{elt['xml:base']}"
      #   elt.remove_attribute("xml:base")
      #   elt.base = nil
      # end

      open(output_file, 'w') do |f|
        IO.copy_stream(output, f)
      end
    end
  end
end
