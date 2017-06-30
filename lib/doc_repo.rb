# frozen_string_literal: true
require "doc_repo/version"

module DocRepo
  require_relative "doc_repo/configuration"
  require_relative 'doc_repo/error'

  autoload :NetHttpAdapter, "doc_repo/net_http_adapter"
  autoload :GithubFile, "doc_repo/github_file"
  autoload :Page, "doc_repo/page"
  autoload :Repository, "doc_repo/repository"
  autoload :Response, "doc_repo/response"
  autoload :ResultHandler, "doc_repo/result_handler"

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end
  end

  def self.configure
    yield(configuration) if block_given?
  end

  def self.request(slug, &block)
    Repository.new(configuration).request(slug, &block)
  end
end
