require 'spec_helper'
require 'open3'

describe "rake master", golden: true do
  specify "builds a master file and links in images" do
    populate_from("examples/images")

    run "rake master"

    expect("build/master/master.xhtml").to match_master
    expect("build/master/images/image1.png").to match_master
  end
end

