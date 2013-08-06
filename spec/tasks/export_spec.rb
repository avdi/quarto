require 'spec_helper'
require 'open3'

describe 'export task', task: true do
  Given {
    @construct.file "Rakefile", <<"END"
require 'quarto/tasks'
END
  }

  context "with markdown sources" do

    Given {
      @construct.file "intro.md", <<END
# Hello, world

This is the intro
END
      @construct.directory "section1" do |d|
        d.file "ch1.md", <<END
# Hello again

This is chapter 1
END
      end
    }

    When {
      run "rake export"
    }

    Then {
      expect(contents("build/exports/intro.html")).to eq(<<END)
<h1 id="hello-world">Hello, world</h1>
<p>This is the intro</p>
END
    }
    And {
      expect(contents("build/exports/section1/ch1.html")).to eq(<<END)
<h1 id="hello-again">Hello again</h1>
<p>This is chapter 1</p>
END
    }
  end

  context "with org-mode sources", org: true do
    Given {
      @construct.file "book.org", <<EOF
* Chapter 1

Hello from Org-Mode!

#+BEGIN_SRC ruby
puts 1 + 1
#+END_SRC

EOF

      @construct.file "Rakefile", <<EOF
require 'quarto'

Quarto.configure do |config|
  config.use :orgmode
  config.orgmode.emacs_load_path << "#{VENDOR_ORG_MODE_DIR}"
end
EOF
    }

    When {
      run "rake export"
    }

    Then {
      expect(contents("build/exports/book.html")).to eq(<<END)
<div id="outline-container-sec-1" class="outline-2">
<h2 id="sec-1">Chapter 1</h2>
<div class="outline-text-2" id="text-1">
<p>
Hello from Org-Mode!
</p>

<div class="org-src-container">

<pre class="src src-ruby">puts 1 + 1
</pre>
</div>
</div>
</div>
END
    }
  end
end
