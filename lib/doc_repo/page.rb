require "doc_repo/converters/markdown_parser"

module DocRepo
  class Page
    attr_accessor :body

    def initialize(file)
      @body = GithubFile.new(default_ext(file)).read_remote_file
    end

    def default_ext(file)
      if File.extname(file).empty?
        "#{file}.md"
      else
        file
      end
    end

    def to_html
      Converters::MarkdownParser.new(
        extensions: %i[
          no_intra_emphasis
          tables
          fenced_code_blocks
          autolink
          strikethrough
          lax_spacing
          superscript
          with_toc_data
        ]
      ).convert(body)
    end

  end
end
