require 'spec_helper'
require 'open3'

describe "rake sections", golden: true do
  specify "with markdown sources" do
    populate_from("examples/markdown-basic")

    run "rake sections"

    expect("build/sections/intro.xhtml").to match_master
    expect("build/sections/section1/ch1.xhtml").to match_master
    expect("build/sections/empty.xhtml").to match_master
  end

  specify "with orgmode sources" do
    populate_from("examples/orgmode-basic")

    run "rake sections"

    expect("build/sections/book.xhtml").to match_master
  end
end
