require 'support/string'
require 'webmock/rspec'

RSpec.describe DocRepo::Page do
  before do
    DocRepo.configure do |c|
      c.org = 'RadiusNetworks'
      c.repo = 'doc_spec'
      c.branch = 'master'
    end
  end

  let(:body){
    <<-END.strip_heredoc
      # A heading

      Some content
    END
  }

  let(:rendered_html){
    <<-END.strip_heredoc
      <h1 id=\"a-heading\">A heading</h1>

      <p>Some content</p>
    END
  }

  it "returns the markdown as html when there is no extension" do
    stub_request(:get, "https://api.github.com/repos/RadiusNetworks/doc_spec/contents/docs/page.md?ref=master")
      .to_return(body: body)

    page = DocRepo::Page.new("page")
    expect(page.to_html).to eq rendered_html
  end

  it "returns the markdown as html when there is a .md extension" do
    stub_request(:get, "https://api.github.com/repos/RadiusNetworks/doc_spec/contents/docs/page.md?ref=master")
      .to_return(body: body)

    page = DocRepo::Page.new("page.md")
    expect(page.to_html).to eq rendered_html
  end
end
