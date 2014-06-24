require "fileutils"

module GoldenChild
  module Helpers
    include FileUtils

    attr_writer :scenario

    # @return [Scenario] the currently active scenario
    def scenario
      @scenario or fail "You must set the scenario first"
    end

    # (see Scenario#populate_from)
    def populate_from(source_dir)
      scenario.populate_from(source_dir, caller)
    end

    # (see Scenario#run)
    def run(*args, ** options, &block)
      scenario.run(*args, caller: caller, ** options)
    end

    # (see Scenario#within_zip)
    def within_zip(*args, &block)
      scenario.within_zip(*args, &block)
    end

  end
end
