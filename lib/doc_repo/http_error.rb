# frozen_string_literal: true

module DocRepo
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
