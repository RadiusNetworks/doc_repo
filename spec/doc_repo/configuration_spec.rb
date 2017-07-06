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

    it "yields itself when given a block" do
      a_config = DocRepo::Configuration.new { |c| c.repo = "Any Repo" }
      expect(a_config.repo).to eq "Any Repo"
    end

    it "defaults to the 'master' branch" do
      expect(default_config.branch).to eq 'master'
    end

    it "defaults to empty cache options" do
      expect(default_config.cache_options).to eq({})
    end

    it "defaults to a null cache store" do
      expect(default_config.cache_store).to be DocRepo::NullCache.instance
    end

    it "defaults to markdown and HTML as documentation formats" do
      expect(default_config.doc_formats).to match_array %w[
        .md
        .markdown
        .htm
        .html
      ]
    end

    it "defaults to a 'docs' root path" do
      expect(default_config.doc_root).to eq 'docs'
    end

    it "defaults to '.md' for the fallback extension" do
      expect(default_config.fallback_ext).to eq '.md'
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
        cache_options
        cache_store
        doc_formats
        doc_root
        fallback_ext
        org
        repo
      ]
    end
  end

  include_examples "has setting", :branch
  include_examples "has setting", :cache_options
  include_examples "has setting", :cache_store
  include_examples "has setting", :doc_formats
  include_examples "has setting", :doc_root
  include_examples "has setting", :fallback_ext
  include_examples "has setting", :org
  include_examples "has setting", :repo

  it "converting to a hash maps all settings to configured values" do
    a_config = DocRepo::Configuration.new
    a_config.branch = "Any Branch"
    a_config.cache_options = "Any Cache Options"
    a_config.cache_store = "Any Cache Store"
    a_config.doc_formats = %w[ .any .formats ]
    a_config.doc_root = "Any Doc Root"
    a_config.fallback_ext = ".anything"
    a_config.org = "Any Org"
    a_config.repo = "Any Repo"
    expect(a_config.to_h).to eq(
      branch: "Any Branch",
      cache_options: "Any Cache Options",
      cache_store: "Any Cache Store",
      doc_formats: %w[ .any .formats ],
      doc_root: "Any Doc Root",
      fallback_ext: ".anything",
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
