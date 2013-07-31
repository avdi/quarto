require "lino/version"
require 'rake'

module Lino
  module_function

  def build_dir
    "build"
  end

  def source_exts
    %W[org md markdown]
  end

  def source_files()
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
    %W[pandoc -o #{export_file} #{source_file}]
  end
end
