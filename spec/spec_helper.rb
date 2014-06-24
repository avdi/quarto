$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require_relative "env"
require "fileutils"
require "pathname"
require "open3"
require "golden_child/rspec"

begin
  # use `bundle install --standalone' to get this...
  require_relative '../bundle/bundler/setup'
rescue LoadError
  # fall back to regular bundler if the developer hasn't bundled standalone
  require 'bundler'
  Bundler.setup
end

require "rspec/given"
require "test_construct/rspec_integration"
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
    raise "Zip file not found: #{zip_file}" unless zip_file.exist?
    base = zip_file.basename
    dir  = Pathname("../../tmp/unzip").expand_path(__FILE__)
    rm_rf(dir) if dir.exist?
    unzip_dir = dir + zip_file.basename(".*")
    mkdir_p unzip_dir
    unzip_succeeded = system(*%W[unzip -qq #{zip_file} -d #{unzip_dir}])
    raise "Could not unzip #{zip_file}" unless unzip_succeeded
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

GoldenChild.configure do |config|
  config.env["VENDOR_ORG_MODE_DIR"] = VENDOR_ORG_MODE_DIR
  config.add_content_filter("*.xhtml") do |file_content|
    timestamp_pattern = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}-\d{2}:\d{2}/
    file_content.gsub(timestamp_pattern, "1970-01-01-T00:00:00Z")
  end
end

RSpec.configure do |config|
  config.include TaskSpecHelpers, task: true

  config.expose_current_running_example_as :example

  config.after :each, task: true do |example|
    # if example.exception
    #   puts
    #   puts
    #   puts "==================== Task Output ===================="
    #   puts @output
    #   puts "==================== End Task Output ===================="
    #   puts
    #   puts
    # end
  end

  config.before :each do |example|
    @construct = example.metadata[:construct]
  end


end
