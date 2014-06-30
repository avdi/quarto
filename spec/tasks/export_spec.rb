require 'spec_helper'
require 'open3'


describe "rake export", golden: true do
  specify "with markdown sources" do
    populate_from "examples/markdown-basic"

    run "rake export"

    expect(%W[build/exports/intro.html
              build/exports/part1/ch1.html]).to match_master
  end

  specify "with orgmode sources" do
    populate_from "examples/orgmode-basic"
    run "rake export"

    expect("build/exports/book.html").to match_master
  end
end
