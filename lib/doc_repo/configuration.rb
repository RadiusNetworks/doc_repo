# frozen_string_literal: true
require 'singleton'

module DocRepo
  class NullCache
    include Singleton
    instance.freeze

    def fetch(name, options = nil)
      yield
    end

    def write(name, value, options = nil)
    end
  end

  class Configuration
    Settings = Module.new
    include Settings

    def self.setting(name, default: nil)
      attr_writer name
      Settings.module_exec do
        attr_reader name
      end
      if default
        define_method(name) do
          super() || default
        end
      end
    end
    private_class_method :setting

    setting :branch, default: "master"

    setting :cache_options, default: {}

    setting :cache_store, default: NullCache.instance

    setting :doc_formats, default: %w[
      .md
      .markdown
      .htm
      .html
    ].freeze

    setting :doc_root, default: "docs"

    setting :fallback_ext, default: ".md"

    setting :org

    setting :repo

    def inspect
      settings = to_h.map { |setting, value| "#{setting}=#{value.inspect}" }
                     .join(", ")
      "#<#{self.class}:0x%014x #{settings}>" % (object_id << 1)
    end

    def to_h
      Settings.instance_methods(_include_super = false)
              .each_with_object({}) { |setting, hash|
                hash[setting] = public_send(setting)
              }
    end
  end
end
