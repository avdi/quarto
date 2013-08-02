require 'spec_helper'
require 'quarto'

describe Quarto do
  include Quarto
  describe 'figuring out sources, exports, and section paths' do
    Given {
      system("git init")
      @construct.file "ch1.md"
      @construct.file "Rakefile"
      @construct.directory "subdir" do |d|
        d.file "ch2.markdown"
        d.file "ch3.org"
        d.file "README.txt"
      end
      @construct.directory "build" do |d|
        d.file "ignore_me.md"
      end
      @construct.file ".gitignore" do |f|
        f << "/scratch\n"
        f << "~*\n"
      end
      @construct.directory "scratch" do |d|
        d.file "scratch.md"
      end
      @construct.file "~foo.md"
      @construct.file "ignored_by_config.md"
      p `git ls-files --others`
      p File.read(".gitignore")
    }

    Given {
      Quarto.configure do |config|
        config.exclude_source("ignored*")
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
      section_files.should == [
        "build/sections/ch1.xhtml",
        "build/sections/subdir/ch2.xhtml",
        "build/sections/subdir/ch3.xhtml",
      ]
    }

    And {
      source_for_export_file("build/exports/ch1.html") == "ch1.md"
    }

    And {
      source_for_export_file("build/exports/subdir/ch3.org") == "subdir/ch3.org"
    }

    And {
      export_for_section_file("build/sections/subdir/ch3.xhtml") ==
        "build/exports/subdir/ch3.html"
    }

  end

  describe 'export commands' do
    Given(:command) {
      export_command_for("ch1.md", "ch1.html")
    }

    Then { command == %W[pandoc --no-highlight -w html5 -o ch1.html ch1.md] }
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
      open("section.xhtml") do |f|
        Nokogiri::XML(f)
      end
    }

    When { normalize_export("export.html", "section.xhtml", "markdown") }
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

  describe 'creating a spine file' do
    Given(:sources) {
      %W[ch1.xhtml ch2.xhtml]
    }

    When{ create_spine_file("spine.xhtml", sources, stylesheets: []) }
    Then {
      expect(File.read("spine.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude" xml:base="..">
  <head>
    <title>Untitled Book</title>
  </head>
  <body>
    <xi:include href="ch1.xhtml" xpointer="xmlns(ns=http://www.w3.org/1999/xhtml)xpointer(//ns:body/*)">
      <xi:fallback>
        <p>[Missing section: ch1.xhtml]</p>
      </xi:fallback>
    </xi:include>
    <xi:include href="ch2.xhtml" xpointer="xmlns(ns=http://www.w3.org/1999/xhtml)xpointer(//ns:body/*)">
      <xi:fallback>
        <p>[Missing section: ch2.xhtml]</p>
      </xi:fallback>
    </xi:include>
  </body>
</html>
END
    }
  end


  describe 'creating a codex file' do
    Given {
      @construct.file("ch1.xhtml", <<EOF)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>ch1</title>
  </head>
  <body>
    <p>This is chapter 1</p>
    <p>Also chapter 1</p>
  </body>
</html>
EOF
      @construct.file("ch2.xhtml", <<EOF)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>ch1</title>
  </head>
  <body>
    <p>This is chapter 2</p>
  </body>
</html>
EOF
      @construct.file("spine.xhtml", <<EOF)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude">
  <head>
    <title>Untitled Book</title>
  </head>
  <body>
    <xi:include href="ch1.xhtml" xpointer="xmlns(ns=http://www.w3.org/1999/xhtml)xpointer(//ns:body/*)">
      <xi:fallback>
        <p>[Missing section: ch1.xhtml]</p>
      </xi:fallback>
    </xi:include>
    <xi:include href="ch2.xhtml" xpointer="xmlns(ns=http://www.w3.org/1999/xhtml)xpointer(//ns:body/*)">
      <xi:fallback>
        <p>[Missing section: ch2.xhtml]</p>
      </xi:fallback>
    </xi:include>
    <xi:include href="ch3.xhtml" xpointer="xmlns(ns=http://www.w3.org/1999/xhtml)xpointer(//ns:body/*)">
      <xi:fallback>
        <p>[Missing section: ch3.xhtml]</p>
      </xi:fallback>
    </xi:include>
  </body>
</html>
EOF
    }

    When{ create_codex_file("codex.xhtml", "spine.xhtml") }
    Then {
      expect(File.read("codex.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude">
  <head>
    <title>Untitled Book</title>
  </head>
  <body>
    <p>This is chapter 1</p>
    <p>Also chapter 1</p>
    <p>This is chapter 2</p>
    <p>[Missing section: ch3.xhtml]</p>
  </body>
</html>
END
    }
  end

  describe "stripping source code" do
    Given(:code) {
      code = <<END


    puts "hello, world
    if true
      puts "goodbye, world
    end

END
    }
    Then{
      expect(strip_listing(code)).to eq(<<END)
puts "hello, world
if true
  puts "goodbye, world
end
END
    }
  end
end
