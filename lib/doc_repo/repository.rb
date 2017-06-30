# frozen_string_literal: true
require 'forwardable'

module DocRepo
  class Repository
    extend Forwardable

    def initialize(config, http_adapter: NetHttpAdapter.new(GITHUB_HOST))
      @config = config.dup.freeze
      @http = http_adapter
    end

    attr_reader :config
    def_delegators :config, :branch, :doc_root, :fallback_ext, :org, :repo

    def request(slug, result_handler: ResultHandler.new)
      yield result_handler
      result = detect(uri_for(slug))
      case
      when result.redirect?
        action = result_handler.fetch(:redirect) {
          raise UnhandledAction.new(:redirect, <<~MSG.chomp)
            no result redirect handler defined for #{result_handler.inspect}
          MSG
        }
        action.call result.url
      when result.success?
        action = result_handler.fetch(:complete) {
          raise UnhandledAction.new(:complete, <<~MSG.chomp)
            no result completion handler defined for #{result_handler.inspect}
          MSG
        }
        action.call result
      when result.not_found?
        action = result_handler.fetch(:not_found) {
          result_handler.fetch(:error) { raise result }
        }
        action.call result
      else
        # TODO: Are we missing other cases?
        action = result_handler.fetch(:error) { raise result }
        action.call result
      end
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
        http.detect(uri)
      end
    end

    def ensure_ext(slug)
      if File.extname(slug).empty?
        "#{slug}#{fallback_ext}"
      else
        slug
      end
    end
  end

  class NetHttpAdapter
    def initialize(host)
    end
  end

  class Redirect
    def initialize(url)
      @url = url
    end
    attr_reader :url
    def redirect?
      true
    end
  end

  class Doc
    def initialize(uri)
    end
    def redirect?
      false
    end
    def success?
      true
    end
  end

  class HttpError < Error
    def initialize(uri, code, message)
      @code = code
      super("#{@code} \"#{message}\"")
    end
    def redirect?
      false
    end
    def success?
      false
    end
    def not_found?
      404 == @code
    end
    def error?
      true
    end
  end
end
