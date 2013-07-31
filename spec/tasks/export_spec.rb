require 'spec_helper'
require 'open3'

describe 'export task' do
  def run(command)
    @output, @status = Open3.capture2e(command)
    unless @status.success?
      raise "Command `#{command}` failed with output:\n#{@output}"
    end
  end

  def contents(filename)
    File.read(filename)
  end

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
