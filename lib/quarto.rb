require "quarto/version"
require "quarto/build"

module Quarto
  def self.build
    verbosity = if Object.const_defined?(:Rake)
                  Rake::FileUtilsExt.verbose
                else
                  true
                end
    @build ||= Build.new do |b|
      b.verbose = true
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
  end

  def self.reset
    @build = nil
  end
end
