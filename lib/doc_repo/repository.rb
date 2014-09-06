module DocRepo
  class Repository
    def respond(slug, &block)
      if %w(.jpg .png .jpeg .svg .css .txt).include? File.extname(slug)
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

