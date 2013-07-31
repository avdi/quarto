require 'spec_helper'
require 'lino'

describe Lino do
  include Lino
  describe 'figuring out sources and exports' do
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
      source_for_export_file("build/exports/ch1.html") ==
        "ch1.md"
    }

    And {
      source_for_export_file("build/exports/subdir/ch3.org") ==
        "subdir/ch3.org"
    }

  end

  describe 'export commands' do
    Given(:command) {
      export_command_for("ch1.md", "ch1.html")
    }

    Then { command == %W[pandoc -o ch1.html ch1.md] }
  end

end
