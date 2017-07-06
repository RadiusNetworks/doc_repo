# frozen_string_literal: true
require_relative 'converters/markdown_parser'
require 'digest'
require 'time'

module DocRepo
  class Doc
    include HttpResult

    # @api private
    module Cache
      attr_reader :cache_key, :cache_version

      def cache_control
        http['Cache-Control']
      end

      def cache_key_with_version
        "#{cache_key}-#{cache_version}"
      end
    end
    include Cache

    def initialize(uri, http_response)
      @http = http_response
      init_result_readers(uri, @http.code)
      @cache_key = uri.dup.freeze

      # The Github raw server currently provides ETags for content. It's
      # possible a change in servers/APIs may cause some content to no longer
      # produce ETags. Additionally, for app cache versioning we have a default
      # opinion that only the raw content important.
      #
      # For these reasons we calculate the cache version based solely on the
      # raw content, ignoring any provided ETags or lack of one. As this cache
      # version is meant to be used for general change comparisons we are not
      # overly concerned with cryptographic level collision prevention or
      # security. We'd rather have something reasonably fast to keep overhead
      # down.
      #
      # As MD5 and SHA1 are roughly equivalent in speed (see
      # benchmarks/digests.rb) we choose the latter as it provides a reduction
      # in collisions at almost no additional cost.
      @cache_version = Digest::SHA1.hexdigest(@http.body.to_s).freeze

      # NOTE: Not set by Github raw site - we include it for future proofing
      @last_modified = Time.httpdate(@http['Last-Modified']).freeze rescue nil
    end

    attr_reader :last_modified

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

    def to_html(_options = {})
      Converters::MarkdownParser.new(
        extensions: %i[
          no_intra_emphasis
          tables
          fenced_code_blocks
          autolink
          strikethrough
          lax_spacing
          superscript
          with_toc_data
        ]
      ).convert(content.to_s)
    end
  end
end
