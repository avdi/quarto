require "spec_helper"

describe "rake pandoc_epub:epub", golden: true do
  it "generates epub" do
    populate_from("examples/pandoc_epub")

    run "rake pandoc_epub:epub"

    within_zip("build/deliverables/untitled-book.epub") do |dir|
      expect("mimetype").to match_master
      expect("content.opf").to match_master
      expect("META-INF/container.xml").to match_master
      within_xml(dir + "META-INF" + "container.xml") do |doc|
        first_rootfile = doc.at_xpath(
            "/ocf:container/ocf:rootfiles/ocf:rootfile",
            "ocf" => ocf_ns)
        expect(first_rootfile["full-path"]).to eq("content.opf")
        expect(first_rootfile["media-type"])
          .to eq("application/oebps-package+xml")
      end
    end
  end
  let(:ocf_ns) {
    "urn:oasis:names:tc:opendocument:xmlns:container"
  }
end
