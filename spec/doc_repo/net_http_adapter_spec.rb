# frozen_string_literal: true

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

end
