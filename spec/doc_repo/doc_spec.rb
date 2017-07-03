# frozen_string_literal: true

RSpec.describe DocRepo::Doc do

  context "a standard document", "with cachable content headers" do
    subject(:a_document) {
      DocRepo::Doc.new("/any/uri", any_http_ok_response)
    }

    let(:any_http_ok_response) {
      instance_double("Net::HTTPOK", code: "200", body: "Any Content Body").tap { |dbl|
        allow(dbl).to receive(:[]) { |key| response_cache_headers[key] }
      }
    }

    let(:response_cache_headers) {
      # Make string keys mutable to allow testing mutations
      {
        "ETag" => String.new("Any ETag"),
        "Last-Modified" => String.new("Sat, 01 Jul 2017 18:18:33 GMT"),
        "Content-Type" => String.new("text/plain"),
      }
    }

    it "is not an error" do
      expect(a_document).not_to be_an_error
    end

    it "is not missing" do
      expect(a_document).not_to be_not_found
    end

    it "is not a redirect" do
      expect(a_document).not_to be_a_redirect
    end

    it "is successful" do
      expect(a_document).to be_a_success
    end

    it "has a numeric status code" do
      expect(a_document.code).to eq 200
    end

    it "has a URI" do
      expect(a_document.uri).to eq "/any/uri"
    end

    it "sets the E-Tag from the cache headers" do
      expect(a_document.etag).to eq("Any ETag").and be_frozen
      expect(response_cache_headers["ETag"]).not_to be_frozen
    end

    it "sets the last modified time from the cache headers" do
      modified_time = Time.gm(2017, 7, 1, 18, 18, 33)
      expect(a_document.last_modified).to eq(modified_time).and be_frozen
      expect(response_cache_headers["Last-Modified"]).not_to be_frozen
    end

    it "sets the content to the response body" do
      expect(a_document.content).to eq "Any Content Body"
    end

    it "sets the content type according to the associated header" do
      expect(a_document.content_type).to eq "text/plain"
    end
  end

  context "a standard document", "with missing headers" do
    subject(:uncachable_document) {
      DocRepo::Doc.new("/any/uri", headerless_http_ok_response)
    }

    let(:headerless_http_ok_response) {
      # Use either `:[] => nil` or `"[]" => nil` as `[]: nil` is invalid Ruby
      instance_double("Net::HTTPOK", "code" => "200", "[]" => nil)
    }

    it "may not have an E-Tag" do
      expect(uncachable_document.etag).to be nil
    end

    it "may not have a last modified timestamp", :aggregate_failures do
      expect(uncachable_document.last_modified).to be nil

      allow(headerless_http_ok_response).to receive(:[]) { |key|
        "Last-Modified" == key ? "0" : nil
      }
      invalid_time = DocRepo::Doc.new("/any/uri", headerless_http_ok_response)
      expect(invalid_time.last_modified).to be nil
    end

    it "may not have any content type" do
      expect(uncachable_document.content_type).to be nil
    end
  end

end
