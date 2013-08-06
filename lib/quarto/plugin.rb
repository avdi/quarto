module Quarto
  class Plugin
    include Rake::DSL

    attr_reader :main

    def initialize(main)
      @main = main
    end

    def enhance_build(build)
      # placeholder
    end

    def define_tasks
      # placeholder
    end
  end
end
