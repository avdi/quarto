require 'lino'

include Lino

desc "Export from source formats to HTML"
task :export => [*export_files]

desc "Generate normalized XHTML versions of exports"
task :sections => [*section_files]

desc "Build a single XHTML file codex combining all sections"
task :codex => codex_file

desc "Strip out code listings for highlighting"
task :skeleton => skeleton_file

directory build_dir
directory export_dir => [build_dir]

export_files.each do |export_file|
  file export_file => [export_dir] do |t|
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
