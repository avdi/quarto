require 'spec_helper'
require 'open3'

describe 'skeleton task', task: true do
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
    run "rake skeleton"
  }

  Then {
    expect(contents("build/skeleton.xhtml")).to eq(<<END)
<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude" xml:base="..">
  <head>
    <title>Untitled Book</title>
  </head>
  <body>
    <xi:include href="build/highlights/3361c5f02e08bd44bde2d42633a2c9be201f7ec4.html">
      <xi:fallback>
        <p>[Missing code listing: build/highlights/3361c5f02e08bd44bde2d42633a2c9be201f7ec4.html]</p>
      </xi:fallback>
    </xi:include>
    <xi:include href="build/highlights/e7b17ea0eeebbd00d08674cf9070d287e24dc68e.html">
      <xi:fallback>
        <p>[Missing code listing: build/highlights/e7b17ea0eeebbd00d08674cf9070d287e24dc68e.html]</p>
      </xi:fallback>
    </xi:include>
  </body>
</html>
END
  }

  And {
    expect(contents("build/listings/3361c5f02e08bd44bde2d42633a2c9be201f7ec4.rb")).to eq(<<END)
puts "hello, world"
END
  }
  And {
    expect(contents("build/listings/e7b17ea0eeebbd00d08674cf9070d287e24dc68e.c")).to eq(<<END)
int main(int argc, char** argv) {
  printf("Hello, world\n")
}
END
  }
end
