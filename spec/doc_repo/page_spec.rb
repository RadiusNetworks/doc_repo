require 'spec_helper'

RSpec.describe DocRepo::Page do
  def tempfile(body)
    Tempfile.open("spec") do |f|
      f.puts body
      f.rewind
      yield f
    end
  end

  it "returns the markdown as html" do
    body = <<-END.strip_heredoc do |file|
      # A heading

      Some content
      END

      stub_request(:get, "https://api.github.com/repos/RadiusNetworks/proximitykit-documentation/contents/docs/page.md?ref=master")
        .to_return(body: body)

      page = DocRepo::Page.new("page")
      expect(page.to_html).to eq <<-END.strip_heredoc
        <h1 id=\"a-heading\">A heading</h1>

        <p>Some content</p>
      END
    end
  end
end
