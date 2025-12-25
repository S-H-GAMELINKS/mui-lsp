# frozen_string_literal: true

module Mui
  module Lsp
    module Handlers
      # Handler for textDocument/formatting responses
      class Formatting < Base
        protected

        def handle_result(result)
          return handle_empty unless result.is_a?(Array) && !result.empty?

          apply_text_edits(result)
        end

        def handle_empty
          @editor.message = "No formatting changes"
        end

        private

        def apply_text_edits(edits)
          buffer = @editor.buffer
          return @editor.message = "No buffer" unless buffer

          # Sort edits in reverse order (bottom to top) to avoid position shifts
          sorted_edits = edits.sort_by do |edit|
            range = edit["range"]
            start_line = range["start"]["line"]
            start_char = range["start"]["character"]
            [-start_line, -start_char]
          end

          # Apply each edit
          changes_count = 0
          sorted_edits.each do |edit|
            apply_single_edit(buffer, edit)
            changes_count += 1
          end

          @editor.message = "Formatted (#{changes_count} change#{"s" unless changes_count == 1})"
        end

        def apply_single_edit(buffer, edit)
          range = edit["range"]
          new_text = edit["newText"]

          start_line = range["start"]["line"]
          start_char = range["start"]["character"]
          end_line = range["end"]["line"]
          end_char = range["end"]["character"]

          # Get current lines
          lines = buffer.lines

          # Build new content
          # Get text before the edit range
          before_text = if start_line < lines.length
                          line = lines[start_line] || ""
                          line[0, start_char] || ""
                        else
                          ""
                        end

          # Get text after the edit range
          after_text = if end_line < lines.length
                         line = lines[end_line] || ""
                         line[end_char..] || ""
                       else
                         ""
                       end

          # Split new_text into lines
          new_lines = new_text.split("\n", -1)

          new_lines = [""] if new_lines.empty?

          # Combine before_text with first new line
          new_lines[0] = before_text + new_lines[0]

          # Combine last new line with after_text
          new_lines[-1] = new_lines[-1] + after_text

          # Replace lines in buffer
          # Delete old lines
          delete_count = end_line - start_line + 1
          delete_count.times do
            buffer.delete_line(start_line) if start_line < buffer.lines.length
          end

          # Insert new lines
          new_lines.each_with_index do |line, idx|
            buffer.insert_line(start_line + idx, line)
          end
        end
      end
    end
  end
end
