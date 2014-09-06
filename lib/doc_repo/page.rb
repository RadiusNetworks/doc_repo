module DocRepo
  class Page
    attr_accessor :body

    def initialize(file)
      @body = GithubFile.new("#{file}.md").read_remote_file
    end

    def to_html
      Converters::Markdown::RedcarpetParser.new(
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
