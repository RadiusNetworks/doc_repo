# frozen_string_literal: true
require 'time'

module DocRepo
  class Doc
    include HttpResult

    def initialize(uri, http_response)
      @http = http_response
      init_result_readers(uri, @http.code)
      @etag = @http['ETag'].dup.freeze

      # NOTE: Not set by Github raw site - we include it for future proofing
      @last_modified = Time.httpdate(@http['Last-Modified']).freeze rescue nil
    end

    attr_reader :etag, :last_modified

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
end
