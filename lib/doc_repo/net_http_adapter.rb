# frozen_string_literal: true
require 'net/http'
require 'time'

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
      resp = http_cache(uri)
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

  private

    def cache_key(uri)
      "#{host}:#{uri}"
    end

    def conditional_headers(expired)
      # Origin servers are supposed to treat `If-None-Match` with higher
      # precedences than `If-Modified-Since` according to the RFC:
      #
      # > A recipient cache or origin server MUST evaluate the request
      # > preconditions defined by this specification in the following order:
      # >
      # > 1.  When recipient is the origin server and If-Match is present,
      # >     evaluate the If-Match precondition:
      # >
      # >     *  if true, continue to step 3
      # >
      # >     *  if false, respond 412 (Precondition Failed) unless it can be
      # >        determined that the state-changing request has already
      # >        succeeded (see Section 3.1)
      # >
      # > 2.  When recipient is the origin server, If-Match is not present, and
      # >     If-Unmodified-Since is present, evaluate the If-Unmodified-Since
      # >     precondition:
      # >
      # >     *  if true, continue to step 3
      # >
      # >     *  if false, respond 412 (Precondition Failed) unless it can be
      # >        determined that the state-changing request has already
      # >        succeeded (see Section 3.4)
      # >
      # > 3.  When If-None-Match is present, evaluate the If-None-Match
      # >     precondition:
      # >
      # >     *  if true, continue to step 5
      # >
      # >     *  if false for GET/HEAD, respond 304 (Not Modified)
      # >
      # >     *  if false for other methods, respond 412 (Precondition Failed)
      # >
      # > 4.  When the method is GET or HEAD, If-None-Match is not present, and
      # >     If-Modified-Since is present, evaluate the If-Modified-Since
      # >     precondition:
      # >
      # >     *  if true, continue to step 5
      # >
      # >     *  if false, respond 304 (Not Modified)
      # >
      # > -- https://tools.ietf.org/html/rfc7232#section-6
      #
      # This allows clients, and caches, some flexibility in how they generate
      # the `If-Modified-Since` header:
      #
      # > When used for cache updates, a cache will typically use the value of
      # > the cached message's Last-Modified field to generate the field value
      # > of If-Modified-Since.  This behavior is most interoperable for cases
      # > where clocks are poorly synchronized or when the server has chosen to
      # > only honor exact timestamp matches (due to a problem with
      # > Last-Modified dates that appear to go "back in time" when the origin
      # > server's clock is corrected or a representation is restored from an
      # > archived backup).  However, caches occasionally generate the field
      # > value based on other data, such as the Date header field of the
      # > cached message or the local clock time that the message was received,
      # > particularly when the cached message does not contain a Last-Modified
      # > field.
      # >
      # > -- https://tools.ietf.org/html/rfc7232#section-3.3
      #
      # However, the Github raw content server (GRC) does not respect this.
      # This may be due to the fact that the GRC does not send a
      # `Last-Modified` header in replies. If we take that into account this
      # behavior _may_ make sense if we assume the GRC  is following the now
      # obsolete HTTP/1.1 RFC 2616:
      #
      # > An HTTP/1.1 origin server, upon receiving a conditional request that
      # > includes both a Last-Modified date (e.g., in an If-Modified-Since or
      # > If-Unmodified-Since header field) and one or more entity tags (e.g.,
      # > in an If-Match, If-None-Match, or If-Range header field) as cache
      # > validators, MUST NOT return a response status of 304 (Not Modified)
      # > unless doing so is consistent with all of the conditional header
      # > fields in the request.
      # >
      # > -- https://tools.ietf.org/html/rfc2616#section-13.3.4
      #
      # So to actually receive `304 Not Modified` replies from GRC, but also
      # try to be compatible with more current servers, this only sets
      # `If-Modified-Since` based on the `Last-Modified` value (i.e. we no
      # longer fall back to the `Date` value).
      preconditions = {
        "If-None-Match" => expired["ETag"],
        "If-Modified-Since" => expired["Last-Modified"],
      }
      preconditions.compact!
      preconditions
    end

    def expired?(resp)
      # TODO: Use `Cache-Control` header when available
      expires_at = resp['Expires']
      expires_at && Time.httpdate(expires_at) < Time.now
    rescue ArgumentError => _e
      # Raised when `Time.parse` cannot parse the value
      #
      # Per the HTTP 1.1 RFC regarding the `Expires` header:
      #
      # > A cache recipient MUST interpret invalid date formats, especially the
      # > value "0", as representing a time in the past (i.e., "already
      # > expired").
      # >
      # > -- https://tools.ietf.org/html/rfc7234#section-5.3
      true
    end

    def http_cache(uri)
      uri_key = cache_key(uri)
      resp = cache.fetch(uri_key, cache_options) {
        Net::HTTP.start(host, opts) { |http| http.get(uri) }
      }
      if expired?(resp)
        resp = refresh(uri, resp)
        cache.write uri_key, resp, cache_options
      end
      resp
    end

    def refresh(uri, expired)
      fresh = Net::HTTP.start(host, opts) { |http|
        http.get(uri, conditional_headers(expired))
      }
      if Net::HTTPNotModified === fresh
        fresh.each_header do |k, v|
          expired[k] = v
        end
        fresh = expired
      end
      fresh
    end
  end
end
