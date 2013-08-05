require 'spec_helper'
require 'open3'

describe 'master task', task: true do
  Given {
    @construct.file "Rakefile", <<END
require 'quarto/tasks'
Quarto.configure do |config|
  config.stylesheets.clear
  config.metadata = false
end
END
    @construct.file "ch1.md", <<END
<p>Before listing 0</p>
```ruby
puts "hello, world"
```
<p>After listing 0</p>
END
    @construct.file "ch2.md", <<END
```c
int main(int argc, char** argv) {
  printf("Hello, world\n")
}
```
END
  }

  When {
    run "rake master"
  }

  Then {
    expect(contents("build/master.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude" xml:base="..">
  <head>
    <title>Untitled Book</title>
    <link rel="schema.DC" href="http://purl.org/dc/elements/1.1/"/>
  </head>
  <body>
    <p>
Before listing 0
</p>
    <div class="highlight"><pre><span class="nb">puts</span> <span class="s2">"hello, world"</span>
</pre></div>
    <p>
After listing 0
</p>
    <div class="highlight"><pre><span class="kt">int</span> <span class="nf">main</span><span class="p">(</span><span class="kt">int</span> <span class="n">argc</span><span class="p">,</span> <span class="kt">char</span><span class="o">**</span> <span class="n">argv</span><span class="p">)</span> <span class="p">{</span>
  <span class="n">printf</span><span class="p">(</span><span class="s">"Hello, world</span>
<span class="s">")</span>
<span class="p">}</span>
</pre></div>
  </body>
</html>
END
  }
end
