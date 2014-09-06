require 'open-uri'

module DocRepo
  class GithubFile

    attr_reader :org, :repo, :branch, :file
    def initialize(file,
                   org: DocRepo.configuration.org,
                   repo: DocRepo.configuration.repo,
                   branch: DocRepo.configuration.branch)
      @file = file
      @org = org
      @repo = repo
      @branch = branch
    end

    def redirect_url
      "https://github.com/#{org}/#{repo}/raw/#{branch}/docs/#{file}"
    end

    def read_remote_file
      open(url(file), headers).read
    rescue OpenURI::HTTPError => e
      raise DocRepo::NotFound
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
      "https://api.github.com/repos/#{org}/#{repo}/contents/docs/#{file}?ref=#{branch}"
    end
  end
end


