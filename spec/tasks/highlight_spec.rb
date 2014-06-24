require "spec_helper"
require "open3"

describe "rake highlight", golden: true do
  it "highlights source listings" do
    populate_from("examples/source-listings")

    run "rake highlight"

    expect("build/highlights/3361c5f02e08bd44bde2d42633a2c9be201f7ec4.html").
        to match_master
    expect("build/highlights/b8f5d0e6fa84ab657a95f4e67d1093abcc9dd3df.html").
        to match_master
  end
end
