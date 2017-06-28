# frozen_string_literal: true

RSpec.describe DocRepo::Configuration do

  shared_examples "has setting" do |setting_name|
    it "allows configuring `#{setting_name}`" do
      a_config = DocRepo::Configuration.new
      expect {
        a_config.public_send "#{setting_name}=", "Any Value"
      }.to change(a_config, setting_name).to "Any Value"
    end
  end

  context "new configuration" do
    subject(:default_config) { DocRepo::Configuration.new }

    it "defaults to the 'master' branch" do
      expect(default_config.branch).to eq 'master'
    end

    it "defaults to a 'docs' root path" do
      expect(default_config.doc_root).to eq 'docs'
    end

    it "has no org set" do
      expect(default_config.org).to be nil
    end

    it "has no repo set" do
      expect(default_config.repo).to be nil
    end

    it "converting to a hash includes all settings" do
      expect(default_config.to_h.keys).to match_array %i[
        branch
        doc_root
        org
        repo
      ]
    end
  end

  include_examples "has setting", :branch
  include_examples "has setting", :doc_root
  include_examples "has setting", :org
  include_examples "has setting", :repo

  it "converting to a hash maps all settings to configured values" do
    a_config = DocRepo::Configuration.new
    a_config.branch = "Any Branch"
    a_config.doc_root = "Any Doc Root"
    a_config.org = "Any Org"
    a_config.repo = "Any Repo"
    expect(a_config.to_h).to eq(
      branch: "Any Branch",
      doc_root: "Any Doc Root",
      org: "Any Org",
      repo: "Any Repo",
    )
  end

  it "doesn't allow creating new settings" do
    expect {
      DocRepo::Configuration.add_setting :new_setting
    }.to raise_error NoMethodError
  end

end
