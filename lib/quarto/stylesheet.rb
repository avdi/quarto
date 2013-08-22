require "quarto/path_helpers"
require "quarto/uri_helpers"
require "base64"

module Quarto
  class Stylesheet
    include PathHelpers
    include UriHelpers

    fattr(:stylesheets)
    fattr(:path)
    fattr(:template_file)   {
      on_fail = ->{ raise "None found: #{potential_templates}" }
      potential_templates.detect(on_fail){|path| File.exist?(path)}
    }
    fattr(:source_file)     { template_file.pathmap("#{source_dir}/%f") }
    fattr(:master_file)     { "#{master_dir}/#{path}" }
    fattr(:source_dir)      { stylesheets.source_dir }
    fattr(:templates_dir)   { stylesheets.templates_dir }
    fattr(:master_dir)      { stylesheets.master_dir }
    fattr(:targets)         { [:all] }

    def initialize(stylesheets, path, options={})
      self.stylesheets = stylesheets
      self.path        = path.ext(".css")
      options.each do |key, value|
        public_send(key, value)
      end
      assert_template_file_exists
    end

    def link_tag
      "<link href='#{relative_master_file}' rel='stylesheet' type='text/css'/>"
    end

    def data_uri
      data_uri_for_file(master_file, "text/css")
    end

    def applicable_to_targets?(*targets)
      self.targets.include?(:all) || (targets & self.targets).any?
    end

    def open(&block)
      open(master_file, &block)
    end

    def to_s
      master_file
    end

    def to_path
      master_file
    end

    def relative_master_file(start_path=stylesheets.main_master_dir)
      rel_path(master_file, start_path)
    end

    def potential_templates
      FileList[
        path.ext(".scss"),
        path,
        "#{templates_dir}/#{path.ext(".scss")}",
      ]
    end

    def assert_template_file_exists
      raise "#{template_file} does not exist" unless File.exist?(template_file)
    end
  end
end
