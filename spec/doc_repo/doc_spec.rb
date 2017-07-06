# frozen_string_literal: true
require 'ostruct'

RSpec.describe DocRepo::Doc do

  context "a standard document", "with cachable content" do
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
        "Last-Modified" => String.new("Sat, 01 Jul 2017 18:18:33 GMT"),
        "Content-Type" => String.new("text/plain"),
        "Cache-Control" => String.new("max-age=300, private, must-revalidate"),
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

    it "uses the URI as the cache key" do
      expect(a_document.cache_key).to eq "/any/uri"
    end

    it "sets the cache version based on the raw content" do
      content_version = Digest::SHA1.hexdigest("Any Content Body")
      expect(a_document.cache_version).to eq(content_version).and be_frozen
    end

    it "has a convenience reader for a versioned cache key" do
      content_version = Digest::SHA1.hexdigest("Any Content Body")
      expect(a_document.cache_key_with_version).to eq "/any/uri-#{content_version}"
    end

    it "allows access to the cache control settings" do
      expect(a_document.cache_control).to eq "max-age=300, private, must-revalidate"
    end
  end

  context "a standard document", "with missing headers" do
    subject(:uncachable_document) {
      DocRepo::Doc.new("/any/uri", headerless_http_ok_response)
    }

    let(:headerless_http_ok_response) {
      # Use either `:[] => nil` or `"[]" => nil` as `[]: nil` is invalid Ruby
      instance_double(
        "Net::HTTPOK",
        "code" => "200",
        "body" => nil,
        "[]" => nil,
      )
    }

    EMPTY_STRING_SHA1 = "da39a3ee5e6b4b0d3255bfef95601890afd80709"

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

    it "always has a cache version" do
      expect(uncachable_document.cache_version).to eq EMPTY_STRING_SHA1
    end

    it "has a convenience reader for a versioned cache key" do
      expect(uncachable_document.cache_key_with_version).to eq "/any/uri-#{EMPTY_STRING_SHA1}"
    end

    it "may not have any cache control settings" do
      expect(uncachable_document.cache_control).to be nil
    end
  end

  describe "converting markdown content to HTML" do
    it "handles empty content" do
      empty_content = OpenStruct.new(body: nil)
      empty_doc = DocRepo::Doc.new("/any/uri", empty_content)
      expect(empty_doc.to_html).to eq ""
    end

    it "does not parse emphasis inside of words" do
      em_content = OpenStruct.new(body: <<~MARKDOWN)
        _this is emphasis_

        this_is_not
      MARKDOWN
      em_doc = DocRepo::Doc.new("/any/uri", em_content)
      expect(em_doc.to_html).to eq <<~HTML
        <p><em>this is emphasis</em></p>

        <p>this_is_not</p>
      HTML
    end

    it "parse tables" do
      tables = OpenStruct.new(body: <<~MARKDOWN)
        | Heading 1 | Heading 2 |
        |-----------|-----------|
        | Content A | Content B |
        | Content C | Content D |

         Heading 3 | Heading 4
        -----------|-----------
         Content E | Content F
         Content G | Content H

        | Left align | Right align | Center align |
        |:-----------|------------:|:------------:|
        | left       |       right |    center    |
        | aligned    |     aligned |   aligned    |
      MARKDOWN
      table_doc = DocRepo::Doc.new("/any/uri", tables)
      expect(table_doc.to_html).to eq <<~HTML
        <table><thead>
        <tr>
        <th>Heading 1</th>
        <th>Heading 2</th>
        </tr>
        </thead><tbody>
        <tr>
        <td>Content A</td>
        <td>Content B</td>
        </tr>
        <tr>
        <td>Content C</td>
        <td>Content D</td>
        </tr>
        </tbody></table>

        <table><thead>
        <tr>
        <th>Heading 3</th>
        <th>Heading 4</th>
        </tr>
        </thead><tbody>
        <tr>
        <td>Content E</td>
        <td>Content F</td>
        </tr>
        <tr>
        <td>Content G</td>
        <td>Content H</td>
        </tr>
        </tbody></table>

        <table><thead>
        <tr>
        <th style="text-align: left">Left align</th>
        <th style="text-align: right">Right align</th>
        <th style="text-align: center">Center align</th>
        </tr>
        </thead><tbody>
        <tr>
        <td style="text-align: left">left</td>
        <td style="text-align: right">right</td>
        <td style="text-align: center">center</td>
        </tr>
        <tr>
        <td style="text-align: left">aligned</td>
        <td style="text-align: right">aligned</td>
        <td style="text-align: center">aligned</td>
        </tr>
        </tbody></table>
      HTML
    end

    it "supports fenced code blocks" do
      fenced_code = OpenStruct.new(body: <<~MARKDOWN)
        Plain Code Block:

        ```
        plain = code
        block { do_something }
        ```

        Language Formatted Block:

        ```ruby
        str = "tagged code"
        # with coments
        block { do_something }
        ```

        Alternative Block Delimiter:

        ~~~js
        alternative = { style: "javascript" }
        ~~~

        End
      MARKDOWN
      code_doc = DocRepo::Doc.new("/any/uri", fenced_code)
      expect(code_doc.to_html).to eq <<~HTML
        <p>Plain Code Block:</p>
        <div class="highlight"><pre><code class="language-" data-lang="">plain = code
        block { do_something }
        </code></pre></div>
        <p>Language Formatted Block:</p>
        <div class="highlight"><pre><code class="language-ruby" data-lang="ruby"><span class="n">str</span> <span class="o">=</span> <span class="s2">"tagged code"</span>
        <span class="c1"># with coments</span>
        <span class="n">block</span> <span class="p">{</span> <span class="n">do_something</span> <span class="p">}</span>
        </code></pre></div>
        <p>Alternative Block Delimiter:</p>
        <div class="highlight"><pre><code class="language-js" data-lang="js"><span class="nx">alternative</span> <span class="o">=</span> <span class="p">{</span> <span class="na">style</span><span class="p">:</span> <span class="s2">"javascript"</span> <span class="p">}</span>
        </code></pre></div>
        <p>End</p>
      HTML
    end

    it "autolinks URLs" do
      embedded_urls = OpenStruct.new(body: <<~MARKDOWN)
        Many people use www.google.com to search. But they really should use
        https://www.duckduckgo.com if they want some security and privacy.

        Is it still common to use http://example.com? What about just example.com

        And no one uses ftp://example.com any more.
      MARKDOWN
      linked_doc = DocRepo::Doc.new("/any/uri", embedded_urls)
      expect(linked_doc.to_html).to eq <<~HTML
        <p>Many people use <a href="http://www.google.com">www.google.com</a> to search. But they really should use
        <a href="https://www.duckduckgo.com">https://www.duckduckgo.com</a> if they want some security and privacy.</p>

        <p>Is it still common to use <a href="http://example.com">http://example.com</a>? What about just example.com</p>

        <p>And no one uses <a href="ftp://example.com">ftp://example.com</a> any more.</p>
      HTML
    end

    it "autolinks email addresses" do
      embedded_email = OpenStruct.new(body: <<~MARKDOWN)
        If you need some help just contant support@example.com.
      MARKDOWN
      mail_doc = DocRepo::Doc.new("/any/uri", embedded_email)
      expect(mail_doc.to_html).to eq <<~HTML
        <p>If you need some help just contant <a href="mailto:support@example.com">support@example.com</a>.</p>
      HTML
    end

    it "supports styling strikethrough content" do
      styled_content = OpenStruct.new(body: <<~MARKDOWN)
        this is ~~good~~ bad
      MARKDOWN
      styled_doc = DocRepo::Doc.new("/any/uri", styled_content)
      expect(styled_doc.to_html).to eq <<~HTML
        <p>this is <del>good</del> bad</p>
      HTML
    end

    it "supports styling superscript content" do
      styled_content = OpenStruct.new(body: <<~MARKDOWN)
        this is the 2^(nd) time
      MARKDOWN
      styled_doc = DocRepo::Doc.new("/any/uri", styled_content)
      expect(styled_doc.to_html).to eq <<~HTML
        <p>this is the 2<sup>nd</sup> time</p>
      HTML
    end

    it "adds HTML anchors to headers" do
      styled_content = OpenStruct.new(body: <<~MARKDOWN)
        # Heading 1

        Content A

        ## Sub-Heading 2

        Content B
      MARKDOWN
      styled_doc = DocRepo::Doc.new("/any/uri", styled_content)
      expect(styled_doc.to_html).to eq <<~HTML
        <h1 id="heading-1">Heading 1</h1>

        <p>Content A</p>

        <h2 id="sub-heading-2">Sub-Heading 2</h2>

        <p>Content B</p>
      HTML
    end

    it "leaves markdown compliant HTML unchanged but may add whitespace" do
      html_content = OpenStruct.new(body: <<~HTML)
        <h1 id="heading-1">Heading 1</h1>
        <p>Content A</p>
        <p>this is <del>good</del> bad</p>
        <p>If you need some help just contant <a href="mailto:support@example.com">support@example.com</a>.</p>
        <p>Plain Code Block:</p>
        <div class="highlight"><pre><code class="language-" data-lang="">plain = code
        block { do_something }
        </code></pre></div>
        <p>Language Formatted Block:</p>
        <div class="highlight"><pre><code class="language-ruby" data-lang="ruby"><span class="n">str</span> <span class="o">=</span> <span class="s2">"tagged code"</span>
        <span class="c1"># with coments</span>
        <span class="n">block</span> <span class="p">{</span> <span class="n">do_something</span> <span class="p">}</span>
        </code></pre></div>
        <p>Alternative Block Delimiter:</p>
        <div class="highlight"><pre><code class="language-js" data-lang="js"><span class="nx">alternative</span> <span class="o">=</span> <span class="p">{</span> <span class="na">style</span><span class="p">:</span> <span class="s2">"javascript"</span> <span class="p">}</span>
        </code></pre></div>
        <h2 id="sub-heading-2">Sub-Heading 2</h2>
        <p>this is the 2<sup>nd</sup> time</p>
        <h3>Sub-Sub-Heading 3</h3>
        <p>Many people use <a href="http://www.google.com">www.google.com</a> to search. But they really should use
        <a href="https://www.duckduckgo.com">https://www.duckduckgo.com</a> if they want some security and privacy.</p>
        <p>And no one uses <a href="ftp://example.com">ftp://example.com</a> any more.</p>
        <table><thead>
        <tr>
        <th style="text-align: left">Left align</th>
        <th style="text-align: right">Right align</th>
        <th style="text-align: center">Center align</th>
        </tr>
        </thead><tbody>
        <tr>
        <td style="text-align: left">left</td>
        <td style="text-align: right">right</td>
        <td style="text-align: center">center</td>
        </tr>
        <tr>
        <td style="text-align: left">aligned</td>
        <td style="text-align: right">aligned</td>
        <td style="text-align: center">aligned</td>
        </tr>
        </tbody></table>
        <p>Final Content</p>
      HTML
      html_doc = DocRepo::Doc.new("/any/uri", html_content)
      expect(html_doc.to_html).to eq <<~HTML
        <h1 id="heading-1">Heading 1</h1>

        <p>Content A</p>

        <p>this is <del>good</del> bad</p>

        <p>If you need some help just contant <a href="mailto:support@example.com">support@example.com</a>.</p>

        <p>Plain Code Block:</p>

        <div class="highlight"><pre><code class="language-" data-lang="">plain = code
        block { do_something }
        </code></pre></div>

        <p>Language Formatted Block:</p>

        <div class="highlight"><pre><code class="language-ruby" data-lang="ruby"><span class="n">str</span> <span class="o">=</span> <span class="s2">"tagged code"</span>
        <span class="c1"># with coments</span>
        <span class="n">block</span> <span class="p">{</span> <span class="n">do_something</span> <span class="p">}</span>
        </code></pre></div>

        <p>Alternative Block Delimiter:</p>

        <div class="highlight"><pre><code class="language-js" data-lang="js"><span class="nx">alternative</span> <span class="o">=</span> <span class="p">{</span> <span class="na">style</span><span class="p">:</span> <span class="s2">"javascript"</span> <span class="p">}</span>
        </code></pre></div>

        <h2 id="sub-heading-2">Sub-Heading 2</h2>

        <p>this is the 2<sup>nd</sup> time</p>

        <h3>Sub-Sub-Heading 3</h3>

        <p>Many people use <a href="http://www.google.com">www.google.com</a> to search. But they really should use
        <a href="https://www.duckduckgo.com">https://www.duckduckgo.com</a> if they want some security and privacy.</p>

        <p>And no one uses <a href="ftp://example.com">ftp://example.com</a> any more.</p>

        <table><thead>
        <tr>
        <th style="text-align: left">Left align</th>
        <th style="text-align: right">Right align</th>
        <th style="text-align: center">Center align</th>
        </tr>
        </thead><tbody>
        <tr>
        <td style="text-align: left">left</td>
        <td style="text-align: right">right</td>
        <td style="text-align: center">center</td>
        </tr>
        <tr>
        <td style="text-align: left">aligned</td>
        <td style="text-align: right">aligned</td>
        <td style="text-align: center">aligned</td>
        </tr>
        </tbody></table>

        <p>Final Content</p>
      HTML
    end
  end

end
