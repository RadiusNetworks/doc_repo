module DocRepo
  class Configuration
    attr_accessor :org, :repo, :branch

    def initialize
      @org    = ENV['DOC_REPO_ORG']
      @repo   = ENV['DOC_REPO_REPONAME']
      @branch = ENV['DOC_REPO_BRANCH'] || "master"
    end
  end
end
