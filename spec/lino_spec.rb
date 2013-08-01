require 'spec_helper'
require 'lino'

describe Lino do
  include Lino
  describe 'figuring out sources, exports, and signature paths' do
    Given {
      @construct.file "ch1.md"
      @construct.file "Rakefile"
      @construct.directory "subdir" do |d|
        d.file "ch2.markdown"
        d.file "ch3.org"
        d.file "README.txt"
      end
    }

    Then {
      source_files.should == [
        "ch1.md",
        "subdir/ch2.markdown",
        "subdir/ch3.org"
      ]
    }

    And {
      export_files.should == [
        "build/exports/ch1.html",
        "build/exports/subdir/ch2.html",
        "build/exports/subdir/ch3.html",
      ]
    }

    And {
      signature_files.should == [
        "build/signatures/ch1.xhtml",
        "build/signatures/subdir/ch2.xhtml",
        "build/signatures/subdir/ch3.xhtml",
      ]
    }

    And {
      source_for_export_file("build/exports/ch1.html") == "ch1.md"
    }

    And {
      source_for_export_file("build/exports/subdir/ch3.org") == "subdir/ch3.org"
    }

    And {
      export_for_signature_file("build/signatures/subdir/ch3.xhtml") ==
        "build/exports/subdir/ch3.html"
    }

  end

  describe 'export commands' do
    Given(:command) {
      export_command_for("ch1.md", "ch1.html")
    }

    Then { command == %W[pandoc -w html5 -o ch1.html ch1.md] }
  end

  describe 'source formats' do
    it 'recognizes .md and .markdown as Makdown' do
      expect(format_of_source_file("foo.md")).to eq("markdown")
      expect(format_of_source_file("foo.markdown")).to eq("markdown")
    end

    it 'recognizes .org as OrgMode' do
      expect(format_of_source_file("foo.org")).to eq("orgmode")
    end
  end

  describe 'normalizing markdown exports' do
    Given {
      @construct.file "export.html", <<END
<h1>This is the title</h1>
<p>This is the content</p>
END
    }

    Given(:result_doc) {
      open("signature.xhtml") do |f|
        Nokogiri::XML(f)
      end
    }

    When { normalize_export("export.html", "signature.xhtml", "markdown") }
    Then {
      expect(result_doc.to_s).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>export</title>
  </head>
  <body>
    <h1>This is the title</h1>
    <p>This is the content</p>
  </body>
</html>
END
    }
  end
end
