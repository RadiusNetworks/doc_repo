require "doc_repo/version"

module DocRepo
  autoload :Configuration, "doc_repo/configuration"
  autoload :GithubFile, "doc_repo/github_file"
  autoload :Page, "doc_repo/page"
  autoload :Repository, "doc_repo/repository"
  autoload :Response, "doc_repo/response"

  BadPageFormat = Class.new(StandardError)
  class NotFound < StandardError
    attr_reader :base
    def initialize(*args, base: $!)
      @base = base
      super(*args)
    end
  end

  class << self
    attr_reader :configuration

    def configuration
      @configuration ||= Configuration.new
    end
  end

  def self.configure
    yield(configuration) if block_given?
  end

  def self.respond_with(slug, &block)
    Repository.new.respond(slug, &block)
  end
end

