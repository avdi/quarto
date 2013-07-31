require 'lino'

include Lino
task :export => [*export_files]

directory build_dir
directory export_dir => [build_dir]

export_files.each do |export_file|
  file export_file => [export_dir] do |t|
    source_file = source_for_export_file(export_file)
    mkdir_p export_file.pathmap("%d")
    sh *export_command_for(source_file, export_file)
  end
end
