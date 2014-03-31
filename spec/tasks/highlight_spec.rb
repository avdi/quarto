require 'spec_helper'
require 'open3'

describe 'highlight task', task: true, test_construct: true do
  Given {
    @construct.file "Rakefile", <<END
require 'quarto/tasks'
END
    @construct.file "ch1.md", <<END
```ruby
puts "hello, world"
```
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
    run "rake highlight"
  }

  Then {
    expect(contents("build/highlights/3361c5f02e08bd44bde2d42633a2c9be201f7ec4.html")).to eq(<<END)
<div class="highlight"><pre><span class="nb">puts</span> <span class="s2">&quot;hello, world&quot;</span>
</pre></div>
END
  }
  And {
    expect(contents("build/highlights/e7b17ea0eeebbd00d08674cf9070d287e24dc68e.html")).to eq(<<END)
<div class="highlight"><pre><span class="kt">int</span> <span class="nf">main</span><span class="p">(</span><span class="kt">int</span> <span class="n">argc</span><span class="p">,</span> <span class="kt">char</span><span class="o">**</span> <span class="n">argv</span><span class="p">)</span> <span class="p">{</span>
  <span class="n">printf</span><span class="p">(</span><span class="s">&quot;Hello, world</span>
<span class="s">&quot;)</span>
<span class="p">}</span>
</pre></div>
END
  }
end
