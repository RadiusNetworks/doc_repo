# frozen_string_literal: true
require 'support/in_memory_cache'

RSpec.describe DocRepo::NetHttpAdapter do

  subject(:an_adapter) { DocRepo::NetHttpAdapter.new("any.host") }

  describe "creating an adapter" do
    it "requires a host" do
      expect {
        DocRepo::NetHttpAdapter.new
      }.to raise_error ArgumentError
    end

    it "creates a defensive frozen copy of the host", :aggregate_failures do
      original_host = String.new("Any Host")  # So it's not frozen
      an_adapter = DocRepo::NetHttpAdapter.new(original_host)
      expect(an_adapter.host).to eq(original_host).and be_frozen
      expect(original_host).not_to be_frozen
      expect {
        original_host.upcase!
      }.not_to change {
        an_adapter.host
      }.from("Any Host")
    end

    it "has default timeouts of 10 seconds" do
      expect(DocRepo::NetHttpAdapter.new("any.host").opts).to include(
        open_timeout: 10,
        read_timeout: 10,
        ssl_timeout: 10,
      )
    end

    it "allows custom opts overwriting defaults" do
      an_adapter = DocRepo::NetHttpAdapter.new(
        "any.host",
        open_timeout: 100,
        verify_depth: 2,
      )
      expect(an_adapter.opts).to include(
        open_timeout: 100,
        verify_depth: 2,
      )
    end

    it "freezes the options once set", :aggregate_failures do
      custom_opts = {
        open_timeout: 100,
        verify_depth: 2,
      }
      an_adapter = DocRepo::NetHttpAdapter.new("any.host", custom_opts)
      expect(an_adapter.opts).to be_frozen
      expect(custom_opts).not_to be_frozen
    end

    it "forces use of SSL", :aggregate_failures do
      default_opts = DocRepo::NetHttpAdapter.new("any.host").opts
      expect(default_opts).to include(use_ssl: true)

      custom_opts = DocRepo::NetHttpAdapter.new("any.host", use_ssl: false).opts
      expect(custom_opts).to include(use_ssl: true)
    end

    it "makes a defensive frozen copy of the cache options", :aggregate_failures do
      cache_opts = { any: :opts }
      cache_adapter = DocRepo::NetHttpAdapter.new(
        "any.host",
        cache_options: cache_opts,
      )
      expect(cache_adapter.cache_options).to eq(cache_opts).and be_frozen
      expect(cache_opts).not_to be_frozen
    end
  end

  it "retrieving a document returns the result" do
    stub_request(:get, "https://any.host/any-document.ext").to_return(
      status: 200,
      body: "Any Document Content",
    )
    expect(an_adapter.retrieve("/any-document.ext")).to be_an_instance_of(
      DocRepo::Doc
    ).and have_attributes(
      code: 200,
      content: "Any Document Content",
    )
  end

  it "retrieving a moved document returns a redirect result" do
    stub_request(:get, "https://any.host/any-document.ext").to_return(
      status: 302,
      headers: { "Location" => "https://new.host/any-location" },
    )
    expect(an_adapter.retrieve("/any-document.ext")).to be_an_instance_of(
      DocRepo::Redirect
    ).and have_attributes(
      code: 302,
      url: "https://new.host/any-location",
    )
  end

  it "retrieving a missing document returns a not found result" do
    stub_request(:get, "https://any.host/any-document.ext").to_return(
      status: [404, "Not Found"],
      body: "Any Error Details",
    )
    expect(an_adapter.retrieve("/any-document.ext")).to be_an_instance_of(
      DocRepo::HttpError
    ).and have_attributes(
      code: 404,
      details: "Any Error Details",
      message: '404 "Not Found"',
    )
  end

  it "retrieving a document causing an HTTP error returns the error" do
    stub_request(:get, "https://any.host/any-document.ext").to_return(
      status: [404, "Not Found"],
      body: "Any Error Details",
    )
    expect(an_adapter.retrieve("/any-document.ext")).to be_an_instance_of(
      DocRepo::HttpError
    ).and have_attributes(
      code: 404,
      details: "Any Error Details",
      message: '404 "Not Found"',
    )
  end

  it "retrieving a document which times out returns a gateway error" do
    stub_request(:get, "https://any.host/any-document.ext").to_timeout
    expect(an_adapter.retrieve("/any-document.ext")).to be_an_instance_of(
      DocRepo::GatewayError
    ).and have_attributes(
      code: 504,
      message: '504 "Gateway Timeout"',
      details: "execution expired",
    )
  end

  it "retrieving a document from a problematic server returns a network error" do
    stub_request(:get, "https://any.host/any-document.ext").to_raise(
      Net::ProtocolError.new("Any Protocol Error")
    )
    expect(an_adapter.retrieve("/any-document.ext")).to be_an_instance_of(
      DocRepo::GatewayError
    ).and have_attributes(
      code: 502,
      message: '502 "Bad Gateway"',
      details: "Any Protocol Error",
    )
  end

  it "converts SSL certificate errors" do
    stub_request(:get, "https://any.host/any-document.ext").to_raise(
      OpenSSL::SSL::SSLError.new(
        "SSL_connect returned=1 errno=0 state=error: certificate verify failed"
      )
    )
    expect(an_adapter.retrieve("/any-document.ext")).to be_an_instance_of(
      DocRepo::GatewayError
    ).and have_attributes(
      code: 502,
      message: '502 "Bad Gateway"',
      details: "SSL_connect returned=1 errno=0 state=error: certificate verify failed",
    )
  end

  it "retrieving a document over a bad network wraps the network error" do
    stub_request(:get, "https://any.host/any-document.ext").to_raise(
      SocketError.new("Any Socket Error")
    )
    expect(an_adapter.retrieve("/any-document.ext")).to be_an_instance_of(
      DocRepo::GatewayError
    ).and have_attributes(
      code: 520,
      message: '520 "Unknown Error"',
      details: "Any Socket Error",
    )
  end

  it "with no cache requests are always made over the network", :aggregate_failures do
    no_cache = DocRepo::NetHttpAdapter.new("any.host")
    stub_request(:get, "https://any.host/any.doc")
      .to_return(status: 200)
      .to_return(status: 500)
    expect(no_cache.retrieve("/any.doc")).to be_an_instance_of(DocRepo::Doc)
    expect(no_cache.retrieve("/any.doc")).to be_an_instance_of(DocRepo::HttpError)
  end

  context "with a cache store" do
    subject(:cached_adapter) {
      DocRepo::NetHttpAdapter.new(
        "any.host",
        cache: mem_cache,
        cache_options: { any: :options },
      )
    }

    let(:mem_cache) { DocRepo::Spec::InMemoryCache.new }

    it "provides the cache options on every request", :aggregate_failures do
      stub_request(:get, /.*/).to_return(status: 200)
      expect {
        cached_adapter.retrieve "/uri/1"
      }.to change {
        mem_cache.options
      }.to eq "any.host:/uri/1" => { any: :options }

      expect {
        cached_adapter.retrieve "/uri/2"
      }.to change {
        mem_cache.options
      }.to eq(
        "any.host:/uri/1" => { any: :options },
        "any.host:/uri/2" => { any: :options },
      )

      # Clear just the options, leave the cache alone
      mem_cache.options.clear

      expect {
        cached_adapter.retrieve "/uri/2"
      }.to change {
        mem_cache.options
      }.to eq "any.host:/uri/2" => { any: :options }
    end

    it "makes an HTTP request when the URI is not cached" do
      http_request = stub_request(:get, /.*/).to_return(status: 200)
      cached_adapter.retrieve "/uri/1"
      expect(http_request).to have_been_requested
    end

    it "stores the HTTP response in the cache" do
      stub_request(:get, /.*/).to_return(
        status: [200, "Custom Code"],
        body: "Any Content Body",
      )
      expect {
        cached_adapter.retrieve "/uri/1"
      }.to change {
        mem_cache.cache
      }.from(
        {}
      ).to(
        "any.host:/uri/1" => an_instance_of(Net::HTTPOK).and(have_attributes(
          code: "200",
          message: "Custom Code",
          body: "Any Content Body",
        ))
      )
    end

    it "re-uses the cached HTTP response" do
      # Populate the cache with a response so we don't have to work with sockets
      stub_request(:get, /.*/)
        .to_return(status: 200, body: "Original Body")
        .to_raise("Cache Not Used!")
      cached_adapter.retrieve "/uri/1"

      # Customize cache to show changes
      cached_response = mem_cache.cache["any.host:/uri/1"]
      cached_response.body = "Cached Body"
      cached_response.content_type = "Cached Content"

      expect(cached_adapter.retrieve("/uri/1")).to be_an_instance_of(
        DocRepo::Doc
      ).and have_attributes(
        code: 200,
        content: "Cached Body",
        content_type: "Cached Content",
      )
    end

    it "performs a conditional GET when cache is expired according to the `Expires` header", :aggregate_failures do
      # Populate the current cache via a response to avoid sockets
      stub_request(:get, /.*/)
        .to_return(
          status: 200,
          body: "Original Body",
          headers: {
            "ETag" => "Any ETag",
            "Last-Modified" => "Sat, 01 Jul 2017 18:18:33 GMT",
            "Expires" => (Time.now + 60).httpdate,  # 1 minute from now
          },
        )
        .to_raise("Cache Not Used!")
      cached_adapter.retrieve "/uri/1"

      # Cache is current so this should return it
      expect(cached_adapter.retrieve("/uri/1").content).to eq "Original Body"

      # Artificially expire cache
      mem_cache.cache["any.host:/uri/1"]["Expires"] = (Time.now - 1).httpdate

      conditional_get = stub_request(:get, %r(.*/uri/1))
        .with(
          headers: {
            "If-None-Match" => "Any ETag",
            "If-Modified-Since" => "Sat, 01 Jul 2017 18:18:33 GMT",
          }
        )
        .to_return(status: 304)
      cached_adapter.retrieve "/uri/1"
      expect(conditional_get).to have_been_requested

      # Falls back to `Date` when `Last-Modified` isn't set
      cache = mem_cache.cache["any.host:/uri/1"]
      cache.delete "Last-Modified"
      cache["Date"] = "Sat, 01 Jul 2017 19:00:01 GMT"
      date_conditional_get = stub_request(:get, %r(.*/uri/1))
        .with(
          headers: {
            "If-None-Match" => "Any ETag",
            "If-Modified-Since" => "Sat, 01 Jul 2017 19:00:01 GMT",
          }
        )
        .to_return(status: 304)
      cached_adapter.retrieve "/uri/1"
      expect(date_conditional_get).to have_been_requested
    end

    it "considers an invalid `Expires` header as expired" do
      # Populate the current cache via a response to avoid sockets
      stub_request(:get, /.*/)
        .to_return(
          status: 200,
          body: "Original Body",
          headers: {
            "ETag" => "Any ETag",
          },
        )
        .to_raise("Cache Not Used!")
      cached_adapter.retrieve "/uri/1"

      # Artificially expire cache with invalid value
      mem_cache.cache["any.host:/uri/1"]["Expires"] = "0"

      conditional_get = stub_request(:get, %r(.*/uri/1))
        .with(
          headers: {
            "If-None-Match" => "Any ETag",
          }
        )
        .to_return(status: 200)
      cached_adapter.retrieve "/uri/1"
      expect(conditional_get).to have_been_requested
    end

    it "refreshes expired cache which hasn't been modified", :aggregate_failures do
      # Populate the current cache via a response to avoid sockets then expire
      stub_request(:get, /.*/)
        .to_return(
          status: 200,
          body: "Original Body",
          headers: {
            "ETag" => "Any ETag",
            "Last-Modified" => "Sat, 01 Jul 2017 18:18:33 GMT",
            "Expires" => (Time.now + 60).httpdate,  # 1 minute from now
            "Content-Type" => "Original Content",
            "Custom-A" => "Original Header",
            "Custom-B" => "Original Header",
          },
        )
        .to_raise("Cache Not Used!")
      stub_request(:get, %r(.*/uri/1))
        .with(
          headers: {
            "If-None-Match" => "Any ETag",
            "If-Modified-Since" => "Sat, 01 Jul 2017 18:18:33 GMT",
          }
        )
        .to_return(
          status: 304,
          body: "Updated Body",
          headers: {
            "ETag" => "Updated ETag",
            "Content-Type" => "Updated Content",
            "Custom-B" => "Updated Header",
          },
        )
      cached_adapter.retrieve "/uri/1"
      mem_cache.cache["any.host:/uri/1"]["Expires"] = (Time.now - 1).httpdate

      expect(cached_adapter.retrieve("/uri/1")).to have_attributes(
        code: 200,
        content: "Original Body",
        content_type: "Updated Content",
        etag: "Updated ETag",
      )
      # Working with headers is painful with Net::HTTP responses
      expect(mem_cache.cache["any.host:/uri/1"].to_hash).to include(
        "etag" => ["Updated ETag"],
        "last-modified" => ["Sat, 01 Jul 2017 18:18:33 GMT"],
        "content-type" => ["Updated Content"],
        "custom-a" => ["Original Header"],
        "custom-b" => ["Updated Header"],
      )
    end

    it "replaces expired cache which has been modified" do
      # Populate the current cache via a response to avoid sockets then expire
      stub_request(:get, /.*/)
        .to_return(
          status: 200,
          body: "Original Body",
          headers: {
            "ETag" => "Any ETag",
            "Last-Modified" => "Sat, 01 Jul 2017 18:18:33 GMT",
            "Expires" => (Time.now + 60).httpdate,  # 1 minute from now
            "Content-Type" => "Original Content",
            "Custom-A" => "Original Header",
            "Custom-B" => "Original Header",
          },
        )
        .to_raise("Cache Not Used!")
      stub_request(:get, %r(.*/uri/1))
        .with(
          headers: {
            "If-None-Match" => "Any ETag",
            "If-Modified-Since" => "Sat, 01 Jul 2017 18:18:33 GMT",
          }
        )
        .to_return(
          status: 201,
          body: "Updated Body",
          headers: {
            "ETag" => "Updated ETag",
            "Content-Type" => "Updated Content",
            "Custom-B" => "Updated Header",
          },
        )
      cached_adapter.retrieve "/uri/1"
      mem_cache.cache["any.host:/uri/1"]["Expires"] = (Time.now - 1).httpdate

      expect(cached_adapter.retrieve("/uri/1")).to have_attributes(
        code: 201,
        content: "Updated Body",
        content_type: "Updated Content",
        etag: "Updated ETag",
      )
      # Working with headers is painful with Net::HTTP responses
      expect(mem_cache.cache["any.host:/uri/1"].to_hash).to eq(
        "etag" => ["Updated ETag"],
        "content-type" => ["Updated Content"],
        "custom-b" => ["Updated Header"],
      )
    end
  end

end
