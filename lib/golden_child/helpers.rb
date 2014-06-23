require "fileutils"

module GoldenChild
  module Helpers
    include FileUtils

    attr_writer :scenario

    def scenario
      @scenario or fail "You must set the scenario first"
    end

    def populate_from(source_dir)
      scenario.populate_from(source_dir, caller)
    end

    def run(*args, **options, &block)
      scenario.run(*args, caller: caller, **options)
    end
  end
end
