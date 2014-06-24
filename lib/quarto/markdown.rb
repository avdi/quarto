require 'quarto'
require 'forwardable'

module Quarto
  class Markdown < Plugin
    include Rake::DSL

    module BuildExt
      extend Forwardable

      attr_accessor :markdown

      def_delegators :markdown,
                     :export_from_markdown,
                     :normalize_markdown_export
    end

    def enhance_build(build)
      build.extend(BuildExt)
      build.markdown = self
      build.extensions_to_source_formats["md"] = "markdown"
      build.extensions_to_source_formats["markdown"] = "markdown"
      build.source_files.include("**/*.md")
      build.source_files.include("**/*.markdown")
    end

    def export_from_markdown(export_file, source_file)
      sh *%W[pandoc --no-highlight -w html5 -o #{export_file} #{source_file}]
    end

    def normalize_markdown_export(export_file, section_file)
      main.normalize_generic_export(export_file, section_file) do |doc|
        source_listing_pre_elts = doc.css("pre[class]>code").map(&:parent)
        source_listing_pre_elts.each do |elt|
          elt["class"] = elt["class"] + " sourceCode"
        end
      end
    end
  end
end
