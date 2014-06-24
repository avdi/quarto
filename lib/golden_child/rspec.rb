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
    # If it looks like an RSpec-Given example, use the example group name.
    #
    # In RSpec-Given the group names the scenario,and the example names are
    # messy source code.
    #
    # TODO: Determine if this is a problem for nested RSpec-Given groups
    scenario_name = if example.description =~ /^\s*Then\b/
                      example.example_group.description
                    else
                      example.full_description
                    end
    self.scenario = GoldenChild::Scenario.new(name: scenario_name)
    example.metadata[:golden_child_scenario] = scenario
    scenario.setup
  end

  config.after(:example, golden: true) do |example|
    scenario.teardown
  end
end

