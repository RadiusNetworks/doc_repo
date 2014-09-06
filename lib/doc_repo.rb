require "doc_repo/version"

require "doc_repo/configuration"
require "doc_repo/github_file"
require "doc_repo/page"
require "doc_repo/repository"
require "doc_repo/response"
require "doc_repo/converters/markdown_parser"

module DocRepo
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

