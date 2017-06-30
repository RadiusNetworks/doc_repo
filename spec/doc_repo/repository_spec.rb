# frozen_string_literal: true

RSpec.describe DocRepo::Repository do

  def build_config(settings)
    DocRepo::Configuration.new.tap { |c|
      settings.each do |name, value|
        c.public_send "#{name}=", value
      end
    }
  end

  def any_handler
    double("DocRepo::ResultHandler").as_null_object
  end

  shared_examples "requesting a slug" do |slug_reader|
    let(:any_slug) { send slug_reader }

    it "requires a block for handling the result" do
      expect {
        subject.request any_slug
      }.to raise_error(/no block given/)
    end

    it "yields a result handler" do
      null_handler = any_handler
      expect { |b|
        subject.request any_slug, result_handler: null_handler, &b
      }.to yield_with_args null_handler
    end
  end

  describe "creating a repository" do
    it "requires a configuration" do
      expect {
        DocRepo::Repository.new
      }.to raise_error ArgumentError
    end

    it "duplicates the configuration to preserve state", :aggregate_failures do
      a_config = DocRepo::Configuration.new
      a_repo = DocRepo::Repository.new(a_config)
      expect(a_repo.config).not_to eq a_config
      expect(a_repo.config.to_h).to eq a_config.to_h
    end

    it "freezes its configuration to preserve state", :aggregate_failures do
      a_config = DocRepo::Configuration.new
      a_repo = DocRepo::Repository.new(a_config)
      expect(a_repo.config).to be_frozen
      expect(a_config).not_to be_frozen
    end
  end

  it "has a repository name" do
    a_repo = DocRepo::Repository.new(build_config(repo: "Any Repo Name"))
    expect(a_repo.repo).to eq "Any Repo Name"
  end

  it "belongs to an org" do
    a_repo = DocRepo::Repository.new(build_config(org: "Any Org"))
    expect(a_repo.org).to eq "Any Org"
  end

  it "has a target branch" do
    a_repo = DocRepo::Repository.new(build_config(branch: "Target Branch"))
    expect(a_repo.branch).to eq "Target Branch"
  end

  it "has a document root path" do
    a_repo = DocRepo::Repository.new(build_config(doc_root: "any/doc/path"))
    expect(a_repo.doc_root).to eq "any/doc/path"
  end

  it "has a fallback extension" do
    a_repo = DocRepo::Repository.new(build_config(fallback_ext: ".anything"))
    expect(a_repo.fallback_ext).to eq ".anything"
  end

  it "has a set of supported document format extensions" do
    a_repo = DocRepo::Repository.new(build_config(doc_formats: %w[.anything]))
    expect(a_repo.doc_formats).to eq %w[.anything]
  end

  describe "generating a URI for a slug" do
    it "defines the full repo path" do
      a_repo = DocRepo::Repository.new(
        build_config(
          org: "AnyOrg",
          repo: "any-repo",
          branch: "target-branch",
          doc_root: "doc/root/path",
          fallback_ext: ".fallback",
        )
      )
      expect(a_repo.uri_for("any-file.ext")).to eq(
        "/AnyOrg/any-repo/target-branch/doc/root/path/any-file.ext"
      )
    end

    it "applies the fallback extension when necessary" do
      a_repo = DocRepo::Repository.new(build_config(fallback_ext: ".fallback"))
      expect(a_repo.uri_for("any-document")).to end_with "/any-document.fallback"
    end

    it "supports a root document path", :aggregate_failures do
      root_conf = build_config(org: "o", repo: "r", branch: "b", doc_root: "/")
      a_repo = DocRepo::Repository.new(root_conf)
      expect(a_repo.uri_for("any-file.ext")).to eq "/o/r/b/any-file.ext"

      root_conf.doc_root = "/root/"
      a_repo = DocRepo::Repository.new(root_conf)
      expect(a_repo.uri_for("any-file.ext")).to eq "/o/r/b/root/any-file.ext"
    end
  end

  describe "requesting a redirectable slug" do
    subject(:a_repo) {
      DocRepo::Repository.new(
        build_config(
          org: "org",
          repo: "repo",
          branch: "branch",
          doc_root: "root",
          doc_formats: %w[ custom ],
        )
      )
    }

    let(:a_redirectable_slug) { "slug.non_document" }

    include_examples "requesting a slug", :a_redirectable_slug

    it "yields the redirect URL to the handler" do
      expect { |b|
        a_repo.request a_redirectable_slug do |result|
          result.redirect(&b)
        end
      }.to yield_with_args <<~URL.chomp
        https://raw.githubusercontent.com/org/repo/branch/root/slug.non_document
      URL
    end

    it "raises when a handler is not configured for redirection" do
      expect {
        a_repo.request a_redirectable_slug do |result|
          # No-Op
        end
      }.to raise_error(
        DocRepo::UnhandledAction,
        /no result redirect handler defined/,
      )
    end
  end

  describe "requesting a document slug" do
    subject(:a_repo) {
      DocRepo::Repository.new(
        build_config(
          org: "org",
          repo: "repo",
          branch: "branch",
          doc_root: "root",
        ),
        http_adapter: successful_http,
      )
    }

    let(:a_doc_slug) { "any-doc-slug.md" }

    let(:successful_http) {
      double("DocRepo::NetHttpAdapter", detect: the_document)
    }

    let(:the_document) {
      DocRepo::Doc.new("uri")
    }

    include_examples "requesting a slug", :a_doc_slug

    it "fetches the document from the remote site" do
      expect(successful_http).to receive(:detect).with(
        "/org/repo/branch/root/any-doc-slug.md"
      )
      a_repo.request(a_doc_slug, result_handler: any_handler) { }
    end

    it "yields the document to the handler" do
      expect { |b|
        a_repo.request a_doc_slug do |result|
          result.complete(&b)
        end
      }.to yield_with_args the_document
    end

    it "raises when a handler is not configured for completion" do
      expect {
        a_repo.request a_doc_slug do |result|
          # No-Op
        end
      }.to raise_error(
        DocRepo::UnhandledAction,
        /no result completion handler defined/,
      )
    end
  end

  describe "requesting a non-existant document slug" do
    subject(:a_repo) {
      DocRepo::Repository.new(
        build_config(
          org: "org",
          repo: "repo",
          branch: "branch",
          doc_root: "root",
        ),
        http_adapter: not_found_http,
      )
    }

    let(:missing_doc_slug) { "missing-doc-slug.md" }

    let(:not_found_http) {
      double("DocRepo::NetHttpAdapter", detect: not_found_result)
    }

    let(:not_found_result) {
      DocRepo::HttpError.new("uri", 404, "Any Message")
    }

    include_examples "requesting a slug", :missing_doc_slug

    it "attempts to fetch the document from the remote site" do
      expect(not_found_http).to receive(:detect).with(
        "/org/repo/branch/root/missing-doc-slug.md"
      )
      a_repo.request(missing_doc_slug, result_handler: any_handler) { }
    end

    it "yields the error result to the `not_found` handler" do
      expect { |b|
        a_repo.request missing_doc_slug do |result|
          result.not_found(&b)
        end
      }.to yield_with_args not_found_result
    end

    it "falls back to yielding the error result to the `error` handler " \
       "without a `not_found` handler" do
      expect { |b|
        a_repo.request missing_doc_slug do |result|
          result.error(&b)
        end
      }.to yield_with_args not_found_result
    end

    it "raises the error result without a configured handler" do
      expect {
        a_repo.request missing_doc_slug do |result|
          # No-Op
        end
      }.to raise_error(DocRepo::HttpError, '404 "Any Message"')
    end
  end

  describe "requesting a document slug", "which causes an error" do
    subject(:a_repo) {
      DocRepo::Repository.new(
        build_config(
          org: "org",
          repo: "repo",
          branch: "branch",
          doc_root: "root",
        ),
        http_adapter: error_http,
      )
    }

    let(:any_doc_slug) { "any-doc-slug.md" }

    let(:error_http) {
      double("DocRepo::NetHttpAdapter", detect: error_result)
    }

    let(:error_result) {
      DocRepo::HttpError.new("uri", 400, "Any Message")
    }

    include_examples "requesting a slug", :any_doc_slug

    it "attempts to fetch the document from the remote site" do
      expect(error_http).to receive(:detect).with(
        "/org/repo/branch/root/any-doc-slug.md"
      )
      a_repo.request(any_doc_slug, result_handler: any_handler) { }
    end

    it "yields the error result to the `error` handler" do
      expect { |b|
        a_repo.request any_doc_slug do |result|
          result.error(&b)
        end
      }.to yield_with_args error_result
    end

    it "raises the error result without a configured handler" do
      expect {
        a_repo.request any_doc_slug do |result|
          # No-Op
        end
      }.to raise_error(DocRepo::HttpError, '400 "Any Message"')
    end
  end

end
