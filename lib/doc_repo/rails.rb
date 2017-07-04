# Monkey patches to work with-in Rails conventions
module DocRepo
  module Rails
    module Modelish
      # Prior to ActiveSupport 5.2 it is assumed the `cache_key` value contains
      # version information.
      module VersionedCacheKey
        def cache_key
          "#{super}-#{cache_version}"
        end
        alias_method :cache_key_with_version, :cache_key
      end
      if Rails.gem_version < Gem::Version.new("5.2.0")
        include VersionedCacheKey
      end

      # For some reason Rails _only_ calls `to_text` for the following:
      #
      #     render html: doc
      #     render body: doc
      #     render plain: doc
      #
      # There's no way for us to know which of these is being called so we
      # can't conditionally provide the raw markdown for `plain`. And without
      # this `to_s` will be called then HTML escaped:
      #
      #     "#&lt;DocRepo::Doc:0x007fabefe8c360&gt;"
      def to_text
        to_html.html_safe
      end

      def updated_at
        last_modified
      end
    end
  end
end

DocRepo::Doc.class_exec do
  include DocRepo::Rails::Modelish
end
