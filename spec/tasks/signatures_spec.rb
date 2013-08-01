require 'spec_helper'
require 'open3'

describe 'signatures task', task: true do
  Given {
    @construct.file "Rakefile", <<END
require 'lino/tasks'
END
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
    run "rake signatures"
  }

  Then {
    expect(contents("build/signatures/intro.xhtml")).to eq(<<END)
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
    expect(contents("build/signatures/section1/ch1.xhtml")).to eq(<<END)
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


end
