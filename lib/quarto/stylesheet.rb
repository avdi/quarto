require "quarto/path_helpers"
require "quarto/uri_helpers"
require "base64"
require "naught"

# This class manages stylesheets.
#
# In a perfect world, we'd have one big stylesheet and all the
# variances between devices would be managed with media
# queries. Meanwhile, back on earth, there are three problems with
# this strategy:
# 1. Many devices don't understand media queries. Whether this means
#    they ignore the rules within @media {...} blocks or apply ALL of
#    them is a big question mark. Other devices only partially support
#    media queries.
# 2. Even if they did all understand media queries, there aren't
#    specific enough queries to account for the diversity of devices
#    out there. There's no media query (that I know of) for "is this
#    an e-ink device?", let alone "is this Apple iBooks?".
# 3. Sometimes the mere presence of an unsupported CSS syntax will
#    throw software for a loop, or generate warnings. E.g. kindlegen
#    spits out warnings for every selector it doesn't happen to
#    support. And I've seen PrinceXML refuse to recognize an entire
#    rule because ONE of the comma-separated selectors in the rule
#    contained a namespaced attribute... even though some of the other
#    comma-separated selectors for the same rule were known to be
#    recognizable by PrinceXML.
#
# The upshot of all this is that for the foreseeable future we're
# still stuck with generating target-specific stylesheets. That's
# what this class helps with.
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
