module DocRepo
  class Response
    attr_reader :type, :params
    def initialize(type, params)
      @type = type ; @params = params
    end

    def self.html(*params)
      self.new :html, params
    end

    def self.redirect(*params)
      self.new :redirect, params
    end

    def html
      yield *params if type == :html
    end

    def redirect
      yield *params if type == :redirect
    end
  end
end

