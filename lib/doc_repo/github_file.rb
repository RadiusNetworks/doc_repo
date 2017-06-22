require 'open-uri'

module DocRepo
  class GithubFile

    attr_reader :org, :repo, :branch, :file, :raw_url
    def initialize(file,
                   org: DocRepo.configuration.org,
                   repo: DocRepo.configuration.repo,
                   branch: DocRepo.configuration.branch)
      @file = file
      @org = org
      @repo = repo
      @branch = branch
      @raw_url = url(file)
    end

    alias_method :redirect_url, :raw_url

    def read_remote_file
      open(raw_url, headers).read
    rescue OpenURI::HTTPError => http_error
      raise DocRepo::NotFound.new(base: http_error)
    end

    def headers
      hash = {
        "Accept"  => "application/vnd.github.v3.raw",
        "User-Agent" => "RadiusNetworks-ProximityKit",
      }

      if ENV["GITHUB_TOKEN"]
        hash["Authorization"] = "token #{ENV["GITHUB_TOKEN"]}"
      end

      hash
    end

    def url(file)
      "https://raw.githubusercontent.com/#{org}/#{repo}/#{branch}/docs/#{file}"
    end
  end
end


