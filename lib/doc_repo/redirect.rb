# frozen_string_literal: true

module DocRepo
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
end
