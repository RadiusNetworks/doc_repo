require 'spec_helper'

RSpec.describe DocRepo::Page do
  it "calls html block with 1 param" do
    resp = DocRepo::Response.html 1
    expect { |b| resp.html(&b) }.to yield_with_args(1)
  end

  it "calls html block with 2 params" do
    resp = DocRepo::Response.html 1, 2
    expect { |b| resp.html(&b) }.to yield_with_args(1, 2)
  end

  it "calls file block with 1 param" do
    resp = DocRepo::Response.html "/path/to/file"
    expect { |b| resp.html(&b) }.to yield_with_args("/path/to/file")
  end
end

