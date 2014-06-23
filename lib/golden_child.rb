require "golden_child/helpers"
require "golden_child/scenario"
require "fileutils"
require "pathname"

module GoldenChild
  class Error < StandardError; end
  class UserError < Error; end

  extend FileUtils

  def self.configuration
    self
  end

  def self.configure
    yield self
  end

  def self.approve(*filenames)
    filenames.each do |fn|
      approve_file(fn)
    end
  end

  def self.approve_file(path)
    path = Pathname(path)
    raise UserError, "No such file #{path}" unless path.exist?
    raise UserError, "Not a file: #{path}" unless path.file?
    rel_path = path.relative_path_from(actual_root)
    unless rel_path
      raise UserError, "File #{path} is not in #{actual_root}"
    end
    master_path = master_root + rel_path
    mkpath master_path.dirname
    cp path, master_path
  end

  def self.actual_root
    golden_path + "actual"
  end

  def self.master_root
    golden_path + "master"
  end

  def self.golden_path
    Pathname("spec/golden")
  end

  class << self
    def project_root
      @project_root ||= Pathname.pwd
    end

    def project_root=(new_root)
      @project_root = Pathname(new_root).expand_path
    end
  end
end
