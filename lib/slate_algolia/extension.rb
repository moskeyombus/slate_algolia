require 'oga'
require 'slate_algolia/parser'
require 'slate_algolia/index'

module Middleman
  module SlateAlgolia
    # Base extension orchestration
    class Extension < Middleman::Extension
      option :parsers, {}, 'Custom tag parsers'
      option :dry_run, false, 'Send data to Algolia or not?'
      option :application_id, '', 'Algolia Application ID'
      option :api_key, '', 'Algolia API Key'
      option :before_index, nil, 'A block to run on each record before it is sent to the index'

      def initialize(app, options_hash = {}, &block)
        super
        merge_parser_defaults(options.parsers)
      end

      def after_build
        parse_content
        index.flush_queue
        index.clean_index
      end

      def index
        @index ||= Index.new(
          application_id: options.application_id,
          api_key: options.api_key,
          dry_run: options.dry_run,
          before_index: options.before_index
        )
      end

      # rubocop:disable AbcSize, MethodLength
      def parsers
        @parsers ||= {
          pre: lambda do |node, section, page|
            languages = node.get('class').split
            languages.delete('highlight')

            if languages.length

              # if the current language is in the list of language tabs
              code_type = if page.metadata[:page]['language_tabs'].include?(languages.first)
                            :tabbed_code
                          else
                            :permanent_code
                          end

              section[code_type] = {} unless section[code_type]

              section[code_type][languages.first.to_sym] = node.text
            end
          end,

          blockquote: lambda do |node, section|
            section[:annotations] = [] unless section[:annotations]
            section[:annotations].push(node.text)
          end,

          h1: lambda do |node|
            {
              id: node.get('id'),
              title: node.text
            }
          end,

          h2: lambda do |node|
            {
              id: node.get('id'),
              title: node.text
            }
          end
        }
      end
      # rubocop:enable AbcSize, MethodLength

      private

      def parse_content
        app.sitemap.where(:algolia_search.equal => true).all.each do |slate_page|
          content_parser = Parser.new(slate_page, parsers)
          next unless content_parser.sections.empty?

          content_parser.sections.each do |section|
            index.queue_object(section)
          end
        end
      end

      def merge_parser_defaults(custom_parsers)
        parsers.merge(custom_parsers)
      end
    end
  end
end
