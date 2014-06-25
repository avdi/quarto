require "spec_helper"

describe "rake site:build", golden: true do
  it "builds a website" do
    populate_from("examples/website")

    run "rake site:build"

    expect("build/site/index.html").to match_master
    expect("build/site/fascicles/001-ch1.html").to match_master
    expect("build/site/fascicles/002-ch2.html").to match_master
  end
end
