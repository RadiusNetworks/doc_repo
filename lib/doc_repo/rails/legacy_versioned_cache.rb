# frozen_string_literal: true

# Monkey patches to work with-in Rails conventions
module DocRepo
  module Rails
    # Prior to ActiveSupport 5.2 it is assumed the `cache_key` value contains
    # version information.
    module VersionedCacheKey
      def cache_key
        "#{super}-#{cache_version}"
      end
      alias_method :cache_key_with_version, :cache_key
    end
  end
end

DocRepo::Doc.class_exec do
  include DocRepo::Rails::VersionedCacheKey
end
