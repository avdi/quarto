require "golden_child/helpers"
require "golden_child/scenario"
require "fileutils"
require "pathname"
require "yaml/store"

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

  def self.approve_file(path_or_shortcode)
    path = case path_or_shortcode
           when /^@\d+$/ then get_path_for_shortcode(path_or_shortcode)
           else
             path_or_shortcode
           end
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

  def self.get_path_for_shortcode(code)
    value = code[/\d+/].to_i
    state_transaction(read_only: true) do |store|
      store[:shortcode_map].invert.fetch(value) do
        fail UserError, "Shortcode not found: #{code}"
      end
    end
  end

  def self.state_transaction(read_only: false)
    config_dir = project_root + ".golden_child"
    mkpath config_dir unless config_dir.exist?
    state_db = config_dir + "state.yaml"
    store = YAML::Store.new(state_db)
    store.transaction(read_only) do
      yield store
    end
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
