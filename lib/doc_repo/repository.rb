# frozen_string_literal: true
require 'forwardable'

module DocRepo
  class Repository
    extend Forwardable

    def initialize(config, http_adapter: nil)
      @config = config.dup.freeze
      @http = http_adapter
      @http ||= NetHttpAdapter.new(
        GITHUB_HOST,
        cache: cache_store,
        cache_options: cache_options,
      )
    end

    attr_reader :config
    def_delegators :config, :branch, :doc_root, :fallback_ext, :org, :repo

    def request(slug, result_handler: ResultHandler.new)
      yield result_handler
      result = detect(uri_for(slug))
      action = handler_for(result, result_handler)
      action.call result
    end

    def uri_for(slug)
      "/#{org}/#{repo}/#{branch}/#{doc_root}/#{ensure_ext(slug)}".squeeze("/")
    end

  private

    GITHUB_HOST = "raw.githubusercontent.com"

    attr_reader :http
    def_delegators :config, :doc_formats, :cache_store, :cache_options

    def redirect_type?(ext)
      !doc_formats.include?(ext)
    end

    def detect(uri)
      if redirect_type?(File.extname(uri))
        Redirect.new("https://#{GITHUB_HOST}#{uri}")
      else
        http.retrieve(uri)
      end
    end

    def ensure_ext(slug)
      if File.extname(slug).empty?
        "#{slug}#{fallback_ext}"
      else
        slug
      end
    end

    def handler_for(result, result_handler)
      case
      when result.redirect?
        result_handler.fetch(:redirect) {
          raise UnhandledAction.new(:redirect, <<~MSG.chomp)
            no result redirect handler defined for #{result_handler.inspect}
          MSG
        }
      when result.success?
        result_handler.fetch(:complete) {
          raise UnhandledAction.new(:complete, <<~MSG.chomp)
            no result completion handler defined for #{result_handler.inspect}
          MSG
        }
      when result.not_found?
        result_handler.fetch(:not_found) {
          result_handler.fetch(:error) { raise result }
        }
      else
        # TODO: Are we missing other cases?
        result_handler.fetch(:error) { raise result }
      end
    end
  end
end
