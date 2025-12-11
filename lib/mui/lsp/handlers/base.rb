# frozen_string_literal: true

module Mui
  module Lsp
    module Handlers
      # Base class for LSP response handlers
      class Base
        attr_reader :editor, :client

        def initialize(editor:, client:)
          @editor = editor
          @client = client
        end

        def handle(result, error)
          if error
            handle_error(error)
          elsif result
            handle_result(result)
          else
            handle_empty
          end
        end

        protected

        def handle_result(result)
          raise NotImplementedError, "Subclass must implement #handle_result"
        end

        def handle_error(error)
          msg = error["message"] || "Unknown LSP error"
          code = error["code"]
          @editor.message = "LSP Error (#{code}): #{msg}"
        end

        def handle_empty
          @editor.message = "No information available"
        end

        def current_file_path
          @editor.current_buffer&.file_path
        end

        def current_uri
          path = current_file_path
          path ? TextDocumentSync.path_to_uri(path) : nil
        end

        def cursor_position
          window = @editor.current_window
          return nil unless window

          {
            line: window.cursor_row,
            character: window.cursor_col
          }
        end

        def markup_to_text(content)
          return nil unless content

          case content
          when String
            content
          when Hash
            value = content["value"] || content[:value]
            case content["kind"] || content[:kind]
            when "markdown"
              # Strip basic markdown formatting
              strip_markdown(value)
            else
              value
            end
          end
        end

        def strip_markdown(text)
          return nil unless text

          text
            .gsub(/```\w*\n?/, "") # Remove code fence markers
            .gsub(/`([^`]+)`/, '\1') # Remove inline code markers
            .gsub(/\*\*([^*]+)\*\*/, '\1') # Remove bold
            .gsub(/\*([^*]+)\*/, '\1') # Remove italic
            .gsub(/^\s*#+\s*/, "") # Remove headings
            .strip
        end
      end
    end
  end
end
