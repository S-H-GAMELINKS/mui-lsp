# frozen_string_literal: true

module Mui
  module Lsp
    module Handlers
      # Handler for textDocument/completion responses
      class Completion < Base
        # CompletionItemKind constants
        module Kind
          TEXT = 1
          METHOD = 2
          FUNCTION = 3
          CONSTRUCTOR = 4
          FIELD = 5
          VARIABLE = 6
          CLASS = 7
          INTERFACE = 8
          MODULE = 9
          PROPERTY = 10
          UNIT = 11
          VALUE = 12
          ENUM = 13
          KEYWORD = 14
          SNIPPET = 15
          COLOR = 16
          FILE = 17
          REFERENCE = 18
          FOLDER = 19
          ENUM_MEMBER = 20
          CONSTANT = 21
          STRUCT = 22
          EVENT = 23
          OPERATOR = 24
          TYPE_PARAMETER = 25
        end

        protected

        def handle_result(result)
          items = extract_items(result)
          return handle_empty if items.empty?

          show_completion_menu(items)
        end

        def handle_empty
          @editor.message = "No completions available"
        end

        private

        def extract_items(result)
          case result
          when Array
            result
          when Hash
            # CompletionList
            result["items"] || []
          else
            []
          end
        end

        def show_completion_menu(items)
          # Format items for display
          formatted = items.map do |item|
            {
              label: item["label"],
              kind: item["kind"],
              detail: item["detail"],
              documentation: item["documentation"],
              insert_text: item["insertText"] || item["label"],
              text_edit: item["textEdit"]
            }
          end

          # Sort by sortText or label
          formatted.sort_by! do |item|
            items.find { |i| i["label"] == item[:label] }&.dig("sortText") || item[:label]
          end

          # Display completion menu or use Mui's completion system
          display_completions(formatted)
        end

        def display_completions(items)
          # For now, show first few items in message
          # TODO: Integrate with Mui's popup menu or completion system
          count = items.length

          # Build a summary message
          first_items = items.first(3).map { |item| item[:label] }
          summary = first_items.join(", ")
          summary += ", ..." if count > 3

          @editor.message = "#{count} completion#{"s" unless count == 1}: #{summary}"

          # Store items for potential insertion
          store_completions(items)
        end

        def store_completions(items)
          @editor.instance_variable_set(:@lsp_completions, items)
        end

        def kind_to_string(kind)
          case kind
          when Kind::TEXT then "Text"
          when Kind::METHOD then "Method"
          when Kind::FUNCTION then "Function"
          when Kind::CONSTRUCTOR then "Constructor"
          when Kind::FIELD then "Field"
          when Kind::VARIABLE then "Variable"
          when Kind::CLASS then "Class"
          when Kind::INTERFACE then "Interface"
          when Kind::MODULE then "Module"
          when Kind::PROPERTY then "Property"
          when Kind::UNIT then "Unit"
          when Kind::VALUE then "Value"
          when Kind::ENUM then "Enum"
          when Kind::KEYWORD then "Keyword"
          when Kind::SNIPPET then "Snippet"
          when Kind::COLOR then "Color"
          when Kind::FILE then "File"
          when Kind::REFERENCE then "Reference"
          when Kind::FOLDER then "Folder"
          when Kind::ENUM_MEMBER then "EnumMember"
          when Kind::CONSTANT then "Constant"
          when Kind::STRUCT then "Struct"
          when Kind::EVENT then "Event"
          when Kind::OPERATOR then "Operator"
          when Kind::TYPE_PARAMETER then "TypeParam"
          else "Unknown"
          end
        end
      end
    end
  end
end
