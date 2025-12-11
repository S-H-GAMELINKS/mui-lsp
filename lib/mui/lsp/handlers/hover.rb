# frozen_string_literal: true

module Mui
  module Lsp
    module Handlers
      # Handler for textDocument/hover responses
      class Hover < Base
        protected

        def handle_result(result)
          contents = result["contents"]
          return handle_empty unless contents

          text = extract_hover_text(contents)
          return handle_empty unless text && !text.empty?

          # Display hover information in echo area or popup
          display_hover(text)
        end

        def handle_empty
          @editor.message = "No hover information"
        end

        private

        def extract_hover_text(contents)
          case contents
          when String
            contents
          when Hash
            markup_to_text(contents)
          when Array
            contents.map { |c| extract_hover_text(c) }.compact.join("\n\n")
          end
        end

        def display_hover(text)
          # Use floating window if available
          if @editor.respond_to?(:show_floating)
            @editor.show_floating(text, max_height: 15)
          else
            # Fallback to echo area display
            lines = text.lines.map(&:chomp)
            @editor.message = if lines.length > 1
                                "#{lines.first} (#{lines.length - 1} more lines)"
                              else
                                lines.first || text
                              end
          end
        end
      end
    end
  end
end
