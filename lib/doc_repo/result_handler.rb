# frozen_string_literal: true
require 'forwardable'

module DocRepo
  class ResultHandler
    extend Forwardable

    def self.handler(*types)
      types.each do |type|
        define_method(type) do |&block|
          raise ArgumentError, "Result handler block required" unless block
          @actions[type] = block
        end
      end
    end
    private_class_method :handler

    handler :complete, :error, :not_found, :redirect

    def initialize
      @actions = {}
    end

    def_delegators :actions, :[], :each, :fetch

    attr_reader :actions
    private :actions
  end
end
