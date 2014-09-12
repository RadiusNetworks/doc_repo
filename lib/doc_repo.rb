require "doc_repo/version"

module DocRepo
  autoload :Configuration, "doc_repo/configuration"
  autoload :GithubFile, "doc_repo/github_file"
  autoload :Page, "doc_repo/page"
  autoload :Repository, "doc_repo/repository"
  autoload :Response, "doc_repo/response"

  BadPageFormat = Class.new(StandardError)
  NotFound      = Class.new(StandardError)

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end

  def self.respond_with(slug, &block)
    Repository.new.respond(slug, &block)
  end
end

