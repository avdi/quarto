require "rake"
require "fattr"

module Quarto
  class Plugin
    include Rake::DSL

    attr_reader :main

    def initialize(main, options={})
      @main = main
      options.each do |name, value|
        public_send(name, value)
      end
    end

    def enhance_build(build)
      # placeholder
    end

    def finalize_build(build)
      # placeholder
    end

    def define_tasks
      # placeholder
    end

    def say(*messages)
      main.say(*messages)
    end
  end
end
