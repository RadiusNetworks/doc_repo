# frozen_string_literal: true

module DocRepo
  Error = Class.new(StandardError)

  class UnhandledAction < Error
    def initialize(action, msg = nil)
      super(msg)
      @action = action.to_s
    end

    attr_reader :action
  end
end
