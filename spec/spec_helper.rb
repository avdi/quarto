$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require_relative "env"
require "fileutils"
require "pathname"
require "open3"

begin
  # use `bundle install --standalone' to get this...
  require_relative '../bundle/bundler/setup'
rescue LoadError
  # fall back to regular bundler if the developer hasn't bundled standalone
  require 'bundler'
  Bundler.setup
end

require "rspec/given"
require "construct"
require "nokogiri"

module TaskSpecHelpers
  include FileUtils

  def ocf_ns
    "urn:oasis:names:tc:opendocument:xmlns:container"
  end

  def run(command)
    @output, @status = Open3.capture2e(command)
    unless @status.success?
      raise "Command `#{command}` failed with output:\n#{@output}"
    end
  end

  def contents(filename)
    File.read(filename)
  end

  def within_zip(zip_file)
    zip_file = Pathname(zip_file)
    base = zip_file.basename
    dir  = Pathname("../../tmp/unzip").expand_path(__FILE__)
    rm_rf(dir) if dir.exist?
    unzip_dir = dir + zip_file.basename(".*")
    mkdir_p unzip_dir
    system(*%W[unzip -qq #{zip_file} -d #{unzip_dir}])
    Dir.chdir(unzip_dir) do
      yield(unzip_dir)
    end
  end

  def within_xml(xml_file)
    doc = open(xml_file) do |f|
      Nokogiri::XML(f)
    end
    yield doc
  end
end

RSpec.configure do |config|
  config.include Construct::Helpers
  config.include TaskSpecHelpers, task: true

  config.around :each do |example|
    within_construct do |c|
      @construct = c
      example.run
    end
  end
end
