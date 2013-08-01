require 'spec_helper'
require 'open3'

describe 'sections task', task: true do
  Given {
    @construct.file "Rakefile", <<END
require 'quarto/tasks'
Quarto.configure do |config|
  config.stylesheets.clear
end
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
    run "rake codex"
  }

  Then {
    expect(contents("build/codex.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude" xml:base="..">
  <head>
    <title>Untitled Book</title>
  </head>
  <body>
    <h1 id="hello-world" xml:base="build/sections/intro.xhtml">Hello, world</h1>
    <p xml:base="build/sections/intro.xhtml">This is the intro</p>
    <h1 id="hello-again" xml:base="build/sections/section1/ch1.xhtml">Hello again</h1>
    <p xml:base="build/sections/section1/ch1.xhtml">This is chapter 1</p>
  </body>
</html>
END
  }


end
