require 'quarto'

include Quarto

desc "Export from source formats to HTML"
task :export => [*export_files]

desc "Generate normalized XHTML versions of exports"
task :sections => [*section_files]

desc "Build a single XHTML file codex combining all sections"
task :codex => codex_file

desc "Strip out code listings for highlighting"
task :skeleton => skeleton_file

desc "Perform source-code highlighting"
task :highlight => [skeleton_file] do |t|
  highlights_needed  = highlights_needed_by(skeleton_file)
  missing_highlights = highlights_needed - FileList["#{highlights_dir}/*.html"]
  sub_task = Rake::MultiTask.new("highlight_dynamic", Rake.application)
  sub_task.enhance(missing_highlights)
  sub_task.invoke
end

directory build_dir
directory export_dir => [build_dir]

export_files.each do |export_file|
  file export_file => [export_dir, source_for_export_file(export_file)] do |t|
    source_file = source_for_export_file(export_file)
    mkdir_p export_file.pathmap("%d")
    sh *export_command_for(source_file, export_file)
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

file spine_file => build_dir do |t|
  create_spine_file(t.name, section_files)
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
