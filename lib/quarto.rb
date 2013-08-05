require "quarto/version"
require "quarto/build"

module Quarto
  def self.build
    verbosity = if Object.const_defined?(:Rake)
                  Rake::FileUtilsExt.verbose
                else
                  true
                end
    @build ||= new_enhanced_build(verbose: verbosity)
  end

  def self.new_enhanced_build(options={})
    Build.new do |b|
      b.verbose = options[:verbose]
      init_callbacks.each do |callback|
        callback.call(b)
      end
    end
  end

  def self.method_missing(method_name, *args, &block)
    build.public_send(method_name, *args, &block)
  end

  def self.define_tasks(&block)
    module_eval(&block)
  end

  def self.init_callbacks
    @init_callbacks ||= []
  end

  def self.enhance_build(&block)
    init_callbacks << block
    if @build
      block.call(build)
    end
  end

  def build
    ::Quarto.build
  end

  def self.configure
    yield build
  end

  def self.reset
    @build = nil
  end
end
