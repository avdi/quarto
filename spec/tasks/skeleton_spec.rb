require 'spec_helper'
require 'open3'

describe 'skeleton task', task: true do
  Given {
    @construct.file "Rakefile", <<END
require 'lino/tasks'
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
    <xi:include href="build/highlights/2c5f3efb5d509c92f1eda3ae6a941fb6645feccc.html">
      <xi:fallback>
        <p>[Missing code listing: build/highlights/2c5f3efb5d509c92f1eda3ae6a941fb6645feccc.html]</p>
      </xi:fallback>
    </xi:include>
    <xi:include href="build/highlights/2276f33dd4c3607a1a3f9d326a3ddb5dc02007da.html">
      <xi:fallback>
        <p>[Missing code listing: build/highlights/2276f33dd4c3607a1a3f9d326a3ddb5dc02007da.html]</p>
      </xi:fallback>
    </xi:include>
  </body>
</html>
END
  }

  And {
    expect(contents("build/listings/2c5f3efb5d509c92f1eda3ae6a941fb6645feccc.rb")).to eq(<<END)
puts "hello, world"
END
  }
  And {
    expect(contents("build/listings/2276f33dd4c3607a1a3f9d326a3ddb5dc02007da.c")).to eq(<<END)
int main(int argc, char** argv) {
  printf("Hello, world\n")
}
END
  }
end
