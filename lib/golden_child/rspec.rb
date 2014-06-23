require "golden_child"

module GoldenChild::RspecMatchers
  extend RSpec::Matchers::DSL

  matcher :match_master do |**options|
    match do |actual|
      @result = scenario.validate(*actual, **options)
      @result.passed?
    end

    failure_message do |actual|
      @result.message
    end
  end
end

RSpec.configure do |config|
  config.include GoldenChild::Helpers, golden: true
  config.include GoldenChild::RspecMatchers, golden: true

  config.before(:example, golden: true) do |example|
    self.scenario = GoldenChild::Scenario.new(name: example.full_description)
    example.metadata[:golden_child_scenario] = scenario
    scenario.setup
  end

  config.after(:example, golden: true) do |example|
    scenario.teardown
  end
end

