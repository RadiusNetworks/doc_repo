# frozen_string_literal: true

module DocRepo
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
end
