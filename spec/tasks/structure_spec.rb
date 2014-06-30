require "spec_helper"

describe "rake structure", golden: true do
  it "generates a coherent book structure from heterogenous inputs" do
    populate_from("examples/structure")

    run "rake structure"

    expect("build/master/master.xhtml").to match_master
    # expect("build/structure.yaml").to match_master
  end
end
