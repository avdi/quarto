require "quarto/version"
require "quarto/build"

module Quarto
  def self.build
     @build ||= Build.new
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
    @build = Build.new
  end
end
