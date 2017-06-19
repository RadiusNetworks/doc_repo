module DocRepo
  class Repository
    REDIRECT_FORMATS = %w[
      .jpg
      .png
      .jpeg
      .svg
      .css
      .txt
    ]

    def respond(slug, &block)
      if REDIRECT_FORMATS.include?(File.extname(slug).downcase)
        yield DocRepo::Response.redirect(get_redirect_url(slug))
      else
        yield DocRepo::Response.html(render_page(slug))
      end
    end

  private

    def render_page(slug)
      DocRepo::Page.new(slug).to_html
    end

    def get_redirect_url(slug)
      GithubFile.new(slug).redirect_url
    end
  end
end

