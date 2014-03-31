require "spec_helper"
require "quarto/pandoc_epub"

module Quarto
  describe PandocEpub do

  end

  describe "pandoc_epub:epub", task: true, test_construct: true do
    Given {
      @construct.file "Rakefile", <<EOF
require "quarto"

Quarto.configure do |c|
  c.use :markdown
  c.use :pandoc_epub
end
EOF

      @construct.file "ch1.md", <<EOF
# The Great American Novel

It was a dark and stormy night.
EOF
    }

    When {
      run "rake pandoc_epub:epub"
    }

    Then {
      within_zip("build/deliverables/untitled-book.epub") do |dir|
        expect(contents("mimetype")).to eq("application/epub+zip")
        expect(dir + "content.opf").to exist
        expect(dir + "META-INF").to exist
        expect(dir + "META-INF" + "container.xml").to exist
        within_xml(dir + "META-INF" + "container.xml") do |doc|
          first_rootfile = doc.at_xpath(
            "/ocf:container/ocf:rootfiles/ocf:rootfile",
            "ocf" => ocf_ns)
          expect(first_rootfile["full-path"]).to eq("content.opf")
          expect(first_rootfile["media-type"])
            .to eq("application/oebps-package+xml")
        end
      end
    }
  end
end
