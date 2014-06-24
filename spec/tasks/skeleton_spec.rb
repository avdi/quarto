require "spec_helper"
require "open3"

describe "rake skeleton", golden: true do
  Given { populate_from("examples/source-listings") }
  When  { run "rake skeleton" }
  Then  { expect("build/skeleton.xhtml").to match_master }
  And   {
    expect("build/listings/3361c5f02e08bd44bde2d42633a2c9be201f7ec4.rb").
        to match_master
  }
  And   {
    expect("build/listings/b8f5d0e6fa84ab657a95f4e67d1093abcc9dd3df.c").
        to match_master
  }
end
