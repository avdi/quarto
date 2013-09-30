require 'spec_helper'
require 'open3'

describe 'sections task', task: true do
  Given {
    @construct.file "Rakefile", <<END
require 'quarto/tasks'
Quarto.configure do |config|
  config.stylesheets.clear
  config.metadata = false
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
    <link rel="schema.DC" href="http://purl.org/dc/elements/1.1/"/>
  </head>
  <body>
    <h1 id="hello-world">Hello, world</h1>
    <p>This is the intro</p>
    <h1 id="hello-again">Hello again</h1>
    <p>This is chapter 1</p>
  </body>
</html>
END
  }

  context 'with custom metadata' do
    Given {
      @construct.file "Rakefile", <<END
require 'quarto/tasks'
Quarto.configure do |config|
  config.stylesheets.clear
  config.metadata = true

  config.author = "Avdi Grimm"
  config.title  = "Hello World, The Book"
  config.description = "The greatest book ever written"
  config.language    = "en-US"
  config.date        = "2013-08-01"
end
END
    }
    Then {
      expect(contents("build/codex.xhtml")).to eq(<<"END")
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude" xml:base="..">
  <head>
    <title>Hello World, The Book</title>
    <link rel="schema.DC" href="http://purl.org/dc/elements/1.1/"/>
    <meta name="author" content="Avdi Grimm"/>
    <meta name="date" content="2013-08-01"/>
    <meta name="subject" content="The greatest book ever written"/>
    <meta name="generator" content="Quarto #{Quarto::VERSION}"/>
    <meta name="DC.title" content="Hello World, The Book"/>
    <meta name="DC.creator" content="Avdi Grimm"/>
    <meta name="DC.description" content="The greatest book ever written"/>
    <meta name="DC.date" content="2013-08-01"/>
    <meta name="DC.language" content="en-US"/>
    <meta name="DC.rights" content="Copyright &#xA9; 2013 Avdi Grimm"/>
  </head>
  <body>
    <h1 id="hello-world">Hello, world</h1>
    <p>This is the intro</p>
    <h1 id="hello-again">Hello again</h1>
    <p>This is chapter 1</p>
  </body>
</html>
END
    }
  end
end
