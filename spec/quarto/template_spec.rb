require "quarto/template"

module Quarto
  describe Template, test_construct: false do
    let(:set) { double("template set") }

    it "knows when it is a partial" do
      expect(Template.new("foo/_bar.html", set)).to be_partial
      expect(Template.new("foo/bar.html", set)).to_not be_partial
    end

    it "can break down a path" do
      t = Template.new("", set)
      path = "templates/foo/bar/baz.html.erb"
      allow(set).to receive(:system_template_dir){ "sys/templates" }
      allow(set).to receive(:user_template_dir){ "templates" }
      allow(set).to receive(:template_expansion_dir){ "expansions" }
      allow(set).to receive(:build_dir){ "build" }

      base_dir, logical_dir, basename = t.path_parts("templates/foo/bar/baz.html.erb")
      expect(base_dir).to eq("templates")
      expect(logical_dir).to eq("foo/bar")
      expect(basename).to eq("baz.html.erb")

      base_dir, logical_dir, basename = t.path_parts("expansions/foo/bar/baz.html.erb")
      expect(base_dir).to eq("expansions")
    end

    it "can map out metamorphoses" do
      t = Template.new("foo/bar/baz.html", set)
      allow(set).to receive(:system_template_dir){ "sys/templates" }
      allow(set).to receive(:user_template_dir){ "templates" }
      allow(set).to receive(:template_expansion_dir){ "build/expansions" }
      allow(set).to receive(:build_dir){ "build" }

      metamorphoses = t.metamorphoses("sys/templates/foo/bar/baz.html.erb")
      expect(metamorphoses).to eq([
          "sys/templates/foo/bar/baz.html.erb",
          "build/foo/bar/baz.html"])

      metamorphoses = t.metamorphoses("sys/templates/foo/bar/baz.html.erb.slim.haml")
      expect(metamorphoses).to eq([
          "sys/templates/foo/bar/baz.html.erb.slim.haml",
          "build/expansions/foo/bar/baz.html.erb.slim",
          "build/expansions/foo/bar/baz.html.erb",
          "build/foo/bar/baz.html"])

      t = Template.new("baz.html", set)
      metamorphoses = t.metamorphoses("templates/baz.html.erb.slim.haml")
      expect(metamorphoses).to eq([
          "templates/baz.html.erb.slim.haml",
          "build/expansions/baz.html.erb.slim",
          "build/expansions/baz.html.erb",
          "build/baz.html"])

      t = Template.new("site/.bowerrc", set)
      metamorphoses = t.metamorphoses("sys/templates/site/.bowerrc")
      expect(metamorphoses).to eq([
          "sys/templates/site/.bowerrc",
          "build/site/.bowerrc"
        ])

    end
  end
end
