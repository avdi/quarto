$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require_relative "env"

begin
  # use `bundle install --standalone' to get this...
  require_relative '../bundle/bundler/setup'
rescue LoadError
  # fall back to regular bundler if the developer hasn't bundled standalone
  require 'bundler'
  Bundler.setup
end

require 'rspec/given'
require 'construct'

module TaskSpecHelpers
  def run(command)
    @output, @status = Open3.capture2e(command)
    unless @status.success?
      raise "Command `#{command}` failed with output:\n#{@output}"
    end
  end

  def contents(filename)
    File.read(filename)
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
