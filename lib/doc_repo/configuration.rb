# frozen_string_literal: true

module DocRepo
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

    setting :doc_root, default: "docs"

    setting :org

    setting :repo

    def to_h
      Settings.instance_methods(_include_super = false)
              .each_with_object({}) { |setting, hash|
                hash[setting] = public_send(setting)
              }
    end
  end
end
