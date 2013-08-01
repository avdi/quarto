require "lino/version"
require 'rake'
require 'nokogiri'
require 'open3'
require 'digest/sha1'

module Lino
  include Rake::DSL

  module_function

  EXTENSIONS_TO_SOURCE_FORMATS = {
    "md" => "markdown",
    "markdown" => "markdown",
    "org" => "orgmode"
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
    </head>
    <body>
    </body>
  </html>
  EOF

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

  def source_files
    FileList["**/*.{#{source_exts.join(',')}}"]
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

  def export_command_for(source_file, export_file)
    %W[pandoc --no-highlight -w html5 -o #{export_file} #{source_file}]
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
    doc = open(export_file) do |f|
      Nokogiri::HTML(f)
    end
    normal_doc = Nokogiri::XML.parse(SECTION_TEMPLATE)
    normal_doc.at_css("body").replace(doc.at_css("body"))
    normal_doc.at_css("title").content = export_file.pathmap("%n")
    open(section_file, "w") do |f|
      format_xml(f) do |pipe_input|
        normal_doc.write_xml_to(pipe_input)
      end
    end
  end

  def source_list_file
    "build/sources"
  end

  def spine_file
    "build/spine.xhtml"
  end

  def create_spine_file(spine_file, section_files)
    doc = Nokogiri::XML.parse(SPINE_TEMPLATE)
    doc.root.add_namespace("xi", "http://www.w3.org/2001/XInclude")
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

  def codex_file
    "build/codex.xhtml"
  end

  def create_codex_file(codex_file, spine_file)
    Open3.pipeline_r(
      %W[xmllint --xinclude --xmlout #{spine_file}],
      # In order to clean up extraneous namespace declarations we need a second
      # xmllint process
      %W[xmllint --format --nsclean --xmlout -]) do |output, wait_thr|
      open(codex_file, 'w') do |f|
        IO.copy_stream(output, f)
      end
    end
  end

  def skeleton_file
    "#{build_dir}/skeleton.xhtml"
  end

  def listings_dir
    "#{build_dir}/listings"
  end

  def highlights_dir
    "#{build_dir}/highlights"
  end

  def create_skeleton_file(skeleton_file, codex_file)
    puts "Scanning #{codex_file} for source code listings"
    skel_doc = open(codex_file) do |f|
      Nokogiri::XML(f)
    end
    skel_doc.css("pre.sourceCode").each_with_index do |pre_elt, i|
      puts "Extracting listing #{i}"
      lang = pre_elt["class"].split[1]
      ext  = {"ruby" => "rb"}.fetch(lang){ lang.downcase }
      puts "Listing has type #{lang}"
      code     = pre_elt.text
      digest   = Digest::SHA1.hexdigest(code)
      listing_path = "#{listings_dir}/#{digest}.#{ext}"
      puts "Creating listing file #{listing_path}"
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
    open(skeleton_file, "w") do |f|
      format_xml(f) do |format_input|
        skel_doc.write_xml_to(format_input)
      end
    end
  end

  def strip_listing(code)
    code.gsub!(/\t/, "  ")
    lines  = code.split("\n")
    first_code_line = lines.index{|l| l =~ /\S/}
    last_code_line  = lines.rindex{|l| l =~ /\S/}
    lines = lines[first_code_line..last_code_line]
    indent = lines.map{|l| l.index(/[^ ]/)}.min
    lines.map{|l| l.slice(indent..-1)}.join("\n") + "\n"
  end

  def format_xml(output_io)
    Open3.popen2(*%W[xmllint --format --xmlout -]) do
      |stdin, stdout, wait_thr|
      yield(stdin)
      stdin.close
      IO.copy_stream(stdout, output_io)
    end
  end
end
