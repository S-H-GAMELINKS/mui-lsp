# frozen_string_literal: true

module Mui
  module Lsp
    module Handlers
      # Handler for textDocument/references responses
      class References < Base
        protected

        def handle_result(result)
          return handle_empty unless result.is_a?(Array) && !result.empty?

          locations = result.map { |loc| Protocol::Location.from_hash(loc) }

          if locations.length == 1
            jump_to_location(locations.first)
          else
            show_location_list(locations)
          end
        end

        def handle_empty
          @editor.message = "No references found"
        end

        private

        def jump_to_location(location)
          file_path = location.file_path
          unless file_path
            @editor.message = "Cannot open: #{location.uri}"
            return
          end

          line = location.range.start.line
          character = location.range.start.character

          # Open the file in current window
          current_buffer = @editor.buffer
          if current_buffer.file_path != file_path
            new_buffer = Mui::Buffer.new
            new_buffer.load(file_path)
            @editor.window.buffer = new_buffer
          end

          # Jump to position
          window = @editor.window
          return unless window

          window.cursor_row = line
          window.cursor_col = character
          window.ensure_cursor_visible

          @editor.message = "#{File.basename(file_path)}:#{line + 1}"
        end

        def show_location_list(locations)
          # Store locations for picker navigation
          @editor.instance_variable_set(:@lsp_picker_locations, locations)
          @editor.instance_variable_set(:@lsp_picker_type, :references)

          # Build picker content
          lines = []
          locations.each_with_index do |loc, idx|
            file_path = loc.file_path || loc.uri
            display_path = File.basename(file_path.to_s)
            line_num = loc.range.start.line + 1
            lines << "#{idx + 1}. #{display_path}:#{line_num}"
          end

          # Open scratch buffer for picker
          content = "References (#{locations.length} found) (\\Enter:open, Ctrl+t:tab, \\q:close)\n\n#{lines.join("\n")}"
          @editor.open_scratch_buffer("[LSP Picker]", content)
        end
      end
    end
  end
end
