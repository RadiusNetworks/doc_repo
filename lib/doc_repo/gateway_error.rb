# frozen_string_literal: true

module DocRepo
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
end
