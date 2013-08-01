require 'lino'

include Lino

desc "Export from source formats to HTML"
task :export => [*export_files]

desc "Generate normalized XHTML versions of exports"
task :sections => [*section_files]

desc "Alias for 'sections' task"
task :normalize => :sections

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
