# frozen_string_literal: true

module DocRepo
  module Spec
    class InMemoryCache
      def initialize
        @cache = {}
        @options = {}
      end

      attr_reader :cache, :options

      def clear
        cache.clear
        options.clear
      end

      def keys
        cache.keys
      end

      def fetch(name, opts = nil, &block)
        options[name] = opts
        cache[name] = cache.fetch(name, &block)
      end

      def write(name, value, opts = nil)
        options[name] = opts
        cache[name] = value
      end
    end
  end
end
