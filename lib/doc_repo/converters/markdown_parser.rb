# Taken and modified from the Jekyll project under the MIT License
# https://github.com/jekyll/jekyll/blob/6849d6a/lib/jekyll/converters/markdown/redcarpet_parser.rb
# https://github.com/jekyll/jekyll/blob/6849d6a/LICENSE
require 'redcarpet'
require 'rouge'
require 'rouge/plugins/redcarpet'

module DocRepo
  module Converters
    class MarkdownParser
      class RougeRenderer < Redcarpet::Render::HTML
        include Rouge::Plugins::Redcarpet

        def add_code_tags(code, lang)
          code = code.to_s
          code = code.sub(
            /<pre>/,
            "<pre><code class=\"language-#{lang}\" data-lang=\"#{lang}\">"
          )
          code = code.sub(/<\/pre>/, "</code></pre>")
        end

        def block_code(code, lang)
          code = "<pre>#{super}</pre>"
          "<div class=\"highlight\">#{add_code_tags(code, lang)}</div>"
        end

      protected

        def rouge_formatter(opts = {})
          Rouge::Formatters::HTML.new(opts.merge(wrap: false))
        end
      end

      def initialize(config)
        @config = config
        @extensions = config.fetch(:extensions, [])
          .each_with_object({}){ |e, h| h[e.to_sym] = true }
        @extensions[:fenced_code_blocks] ||= !@extensions.fetch(:no_fenced_code_blocks, false)
        @extensions[:fenced_code_blocks] ||= !@extensions[:no_fenced_code_blocks]

        render_class = config.fetch(:render_with, RougeRenderer)
        @renderer = render_class.new(@extensions)
        if extensions.fetch(:smart, false)
          @renderer.extend Redcarpet::Render::SmartyPants
        end
      end

      def convert(content)
        markdown = Redcarpet::Markdown.new(renderer, extensions)
        markdown.render(content)
      end

      attr_reader :config, :extensions, :renderer
      private :config, :extensions, :renderer
    end
  end
end
