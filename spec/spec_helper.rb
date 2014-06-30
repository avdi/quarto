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

module SpecHelpers
  def within_xml(xml_file)
    doc = open(xml_file) do |f|
      Nokogiri::XML(f)
    end
    yield doc
  end
end

GoldenChild.configure do |config|
  config.env["VENDOR_ORG_MODE_DIR"] = VENDOR_ORG_MODE_DIR
  config.add_content_filter("*.xhtml", "**/content.opf") do |file_content|
    timestamp_pattern = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}((-\d{2}:\d{2})|Z)/
    file_content.gsub(timestamp_pattern, "1970-01-01-T00:00:00Z")
  end
  config.add_content_filter("**/content.opf") do |file_content|
    urn_pattern = /urn:uuid:[[:alnum:]-]+/
    file_content.gsub(urn_pattern, "urn:uuid:FAKE-FAKE-FAKE")
  end
  # 2014-06-29 Sun 23:30
  config.add_content_filter("*.xhtml") do |file_content|
    file_content.gsub(/\d{4}-\d{2}-\d{2} \w{3} \d{2}:\d{2}/,
                      "1970-01-01 Tue 00:00")
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
  config.expose_current_running_example_as :example

  config.before :each do |example|
    @construct = example.metadata[:construct]
  end
end
