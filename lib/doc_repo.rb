# frozen_string_literal: true
require "doc_repo/version"

module DocRepo
  require_relative "doc_repo/configuration"
  require_relative "doc_repo/error"

  # HTTP Adapter and Results
  autoload :NetHttpAdapter, "doc_repo/net_http_adapter"
  autoload :HttpResult, "doc_repo/http_result"
  autoload :Doc, "doc_repo/doc"
  autoload :Redirect, "doc_repo/redirect"
  autoload :HttpError, "doc_repo/http_error"
  autoload :GatewayError, "doc_repo/gateway_error"

  autoload :Repository, "doc_repo/repository"
  autoload :ResultHandler, "doc_repo/result_handler"

  if defined?(Rails)
    require_relative "doc_repo/rails"
  end

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
