# frozen_string_literal: true
require 'net/http'

module DocRepo
  # @api private
  class NetHttpAdapter
    # Net::HTTP default timeouts of 60 seconds are too long for our purposes
    DEFAULT_OPTS = {
      open_timeout: 10,
      read_timeout: 10,
      ssl_timeout: 10,
    }.freeze

    # HTTP Status Codes
    BAD_GATEWAY     = 502
    GATEWAY_TIMEOUT = 504
    UNKNOWN_ERROR   = 520

    def initialize(host, cache: NullCache.instance, cache_options: {}, **opts)
      @host = host.dup.freeze
      @opts = DEFAULT_OPTS.dup.merge!(opts)
      # Always force SSL
      @opts[:use_ssl] = true
      @opts.freeze
      @cache = cache
      @cache_options = cache_options.dup.freeze
    end

    attr_reader :host, :opts

    attr_reader :cache, :cache_options
    private :cache

    def retrieve(uri)
      resp = Net::HTTP.start(host, opts) { |http| http.get(uri) }
      case resp
      when Net::HTTPRedirection
        Redirect.new(
          resp['Location'],
          code: resp.code,
          headers: resp.to_hash,
        )
      when Net::HTTPSuccess
        Doc.new(uri, resp)
      else
        HttpError.new(uri, resp)
      end
    rescue Timeout::Error => timeout
      # Covers Net::OpenTimeout, Net::ReadTimeout, etc.
      GatewayError.new(uri, code: GATEWAY_TIMEOUT, cause: timeout)
    rescue Net::HTTPBadResponse,
           Net::ProtocolError,
           OpenSSL::SSL::SSLError => protocol_error
      # Docs state `Net::HTTPBadResponse` is raised when there is a protocol
      # error. It's unclear whether all protocol errors are wrapped so we
      # handle both here.
      GatewayError.new(uri, code: BAD_GATEWAY, cause: protocol_error)
    rescue => e
      # Covers IOError, Errno::*, and SocketError
      GatewayError.new(uri, code: UNKNOWN_ERROR, cause: e)
    end
  end

  module HttpResult
    def init_result_readers(uri, code)
      @uri = uri.to_s.freeze
      @code = code.to_i
    end
    protected :init_result_readers

    attr_reader :code, :uri

    def error?
      false
    end

    def not_found?
      false
    end

    def redirect?
      false
    end

    def success?
      false
    end
  end

  class Redirect
    include HttpResult

    def initialize(url, code: 302, headers: {})
      init_result_readers(url, code)
      @headers = headers.freeze
    end

    alias_method :url, :uri
    alias_method :location, :url

    def redirect?
      true
    end
  end

  class Doc
    include HttpResult

    def initialize(uri, http_response)
      @http = http_response
      init_result_readers(uri, @http.code)
    end

    attr_reader :http
    private :http

    def content
      http.body
    end

    def content_type
      # NOTE: The Github raw site does not respond with anything other than
      # `text/plain` for general HTTP errors.
      http['Content-Type']
    end

    def success?
      true
    end
  end

  class GatewayError < Error
    include HttpResult

    def initialize(uri, code:, cause:)
      init_result_readers(uri, code)
      @cause = cause
      message = case code
                when NetHttpAdapter::BAD_GATEWAY
                  '502 "Bad Gateway"'
                when NetHttpAdapter::GATEWAY_TIMEOUT
                  '504 "Gateway Timeout"'
                else
                  name = if defined?(::Rack::Utils::HTTP_STATUS_CODES)
                           ::Rack::Utils::HTTP_STATUS_CODES[code.to_i]
                         else
                           "Unknown Error"
                         end
                  "#{code} #{name.dump}"
                end
      super(message)
    end

    # Wrap exception as normal
    attr_reader :cause

    def details
      cause.message
    end

    def error?
      true
    end
  end

  class HttpError < Error
    include HttpResult

    def initialize(uri, http_response)
      @http = http_response
      init_result_readers(uri, @http.code)
      message = @http.code
      message += ' ' + @http.message.dump if @http.message
      super(message)
    end

    attr_reader :http
    private :http

    def details
      # NOTE: The Github raw site does not respond with anything other than
      # `text/plain` for general HTTP errors.
      http.body
    end

    def not_found?
      404 == code
    end

    def error?
      true
    end
  end
end
