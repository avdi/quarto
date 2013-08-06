require 'spec_helper'
require 'open3'

describe 'sections task', task: true do
  Given {
    @construct.file "Rakefile", <<END
require 'quarto/tasks'
require 'quarto/orgmode'

Quarto.configure do |config|
  config.orgmode.emacs_load_path << "#{VENDOR_ORG_MODE_DIR}"
end
END
  }

  context "with markdown" do
    Given {
      @construct.file "intro.md", <<END
# Hello, world

This is the intro
END
      @construct.file "empty.md", " "
      @construct.directory "section1" do |d|
        d.file "ch1.md", <<END
# Hello again

This is chapter 1
END
      end
    }

    When {
      run "rake sections"
    }

    Then {
      expect(contents("build/sections/intro.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>intro</title>
  </head>
  <body>
    <h1 id="hello-world">Hello, world</h1>
    <p>This is the intro</p>
  </body>
</html>
END
    }
    And {
      expect(contents("build/sections/section1/ch1.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>ch1</title>
  </head>
  <body>
    <h1 id="hello-again">Hello again</h1>
    <p>This is chapter 1</p>
  </body>
</html>
END
    }
    And {
      expect(contents("build/sections/empty.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>empty</title>
  </head>
  <body>
    <!--No content for build/exports/empty.html-->
  </body>
</html>
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
      run "rake sections"
    }

    Then {
      expect(contents("build/sections/book.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>book</title>
  </head>
  <body>
    <div id="outline-container-sec-1" class="outline-2">
      <h2 id="sec-1">Chapter 1</h2>
      <div class="outline-text-2" id="text-1">
        <p>
Hello from Org-Mode!
</p>
        <pre class="sourceCode ruby">
          <code>puts 1 + 1
</code>
        </pre>
      </div>
    </div>
  </body>
</html>
END
    }
  end
end
