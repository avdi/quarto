require 'spec_helper'
require 'open3'

describe "rake signatures", golden: true do
  specify "with markdown sources" do
    populate_from("examples/markdown-basic")

    run "rake signatures"

    expect("build/signatures/intro.xhtml").to match_master
    expect("build/signatures/part1/ch1.xhtml").to match_master
    expect("build/signatures/empty.xhtml").to match_master
  end

  specify "with orgmode sources" do
    populate_from("examples/orgmode-basic")

    run "rake signatures"

    expect("build/signatures/book.xhtml").to match_master
  end
end
