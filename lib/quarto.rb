require "quarto/version"
require "quarto/build"

module Quarto
  def self.build
    verbosity = if Object.const_defined?(:Rake)
                  Rake::FileUtilsExt.verbose
                else
                  true
                end
    @build ||= new_build(verbose: verbosity)
  end

  def self.new_build(options={})
    Build.new do |b|
      b.verbose = options[:verbose]
    end
  end

  def self.method_missing(method_name, *args, &block)
    build.public_send(method_name, *args, &block)
  end

  def build
    ::Quarto.build
  end

  def self.configure
    yield build
    build.define_tasks
  end

  def self.reconfigure(&block)
    Rake.application.clear
    reset
    configure(&block)
  end

  def self.reset
    @build = nil
  end
end
