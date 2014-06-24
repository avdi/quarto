require 'spec_helper'
require 'open3'

describe "rake codex", golden: true do
  specify "with minimal config" do
    populate_from("examples/minimal")

    run "rake codex"

    expect("build/codex.xhtml").to match_master
  end

  specify "with custom metadata" do
    populate_from("examples/metadata")

    run "rake codex"

    expect("build/codex.xhtml").to match_master
  end
end
