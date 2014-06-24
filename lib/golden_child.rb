require "golden_child/helpers"
require "golden_child/scenario"
require "golden_child/configuration"
require "fileutils"
require "pathname"
require "yaml/store"
require "forwardable"

module GoldenChild
  class Error < StandardError;
  end
  class UserError < Error;
  end

  extend FileUtils
  extend SingleForwardable

  def_delegators :configuration, :golden_path, :project_root, :master_root,
      :actual_root
  def_delegators :configuration, :get_path_for_shortcode

  # @return [GoldenChild::Configuration]
  def self.configuration
    @configuration ||= Configuration.new
  end

  # @yield [GoldenChild::Configuration] the global configuration
  def self.configure
    yield configuration
  end

  # @param [Array<String, Pathname>] paths or shortcodes for files to accept
  def self.accept(*filenames)
    filenames.each do |fn|
      accept_file(fn)
    end
  end

  def self.remove(*filenames)
    filenames.each do |fn|
      remove_master_file(fn)
    end
  end

  def self.accept_file(path_or_shortcode)
    path = resolve_path(path_or_shortcode)
    master_path = find_master_for(path)
    mkpath master_path.dirname
    cp path, master_path
  end


  def self.remove_master_file(path_or_shortcode)
    path = resolve_path(path_or_shortcode)
    master_path = find_master_for(path)
    rm master_path
  end

  # @return [Pathname]
  def self.resolve_path(path_or_shortcode)
    path = case path_or_shortcode
    when /^@\d+$/
      get_path_for_shortcode(path_or_shortcode)
    else
      path_or_shortcode
    end
    Pathname(path)
  end

  def self.find_master_for(path)
    raise UserError, "No such file #{path}" unless path.exist?
    raise UserError, "Not a file: #{path}" unless path.file?
    rel_path = path.relative_path_from(actual_root)
    unless rel_path
      raise UserError, "File #{path} is not in #{actual_root}"
    end
    master_root + rel_path
  end
end
