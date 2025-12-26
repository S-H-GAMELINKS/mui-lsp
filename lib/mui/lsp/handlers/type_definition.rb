# frozen_string_literal: true

module Mui
  module Lsp
    module Handlers
      # Handler for textDocument/typeDefinition responses
      class TypeDefinition < Base
        protected

        def handle_result(result)
          locations = normalize_locations(result)
          return handle_empty if locations.empty?

          if locations.length == 1
            jump_to_location(locations.first)
          else
            show_location_list(locations)
          end
        end

        def handle_empty
          @editor.message = "No type definition found"
        end

        private

        def normalize_locations(result)
          case result
          when Array
            result.map { |loc| parse_location(loc) }.compact
          when Hash
            location = parse_location(result)
            location ? [location] : []
          else
            []
          end
        end

        def parse_location(data)
          return nil unless data

          # Handle both Location and LocationLink
          if data["targetUri"]
            # LocationLink
            Protocol::Location.new(
              uri: data["targetUri"],
              range: data["targetSelectionRange"] || data["targetRange"]
            )
          elsif data["uri"]
            # Location
            Protocol::Location.from_hash(data)
          end
        end

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
            # Need to open a different file
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
          @editor.instance_variable_set(:@lsp_picker_type, :type_definition)

          # Build picker content
          lines = []
          locations.each_with_index do |loc, idx|
            file_path = loc.file_path || loc.uri
            display_path = File.basename(file_path.to_s)
            line_num = loc.range.start.line + 1
            lines << "#{idx + 1}. #{display_path}:#{line_num}"
          end

          # Open scratch buffer for picker
          content = "Type Definitions (\\Enter:open, Ctrl+t:tab, \\q:close)\n\n#{lines.join("\n")}"
          @editor.open_scratch_buffer("[LSP Picker]", content)
        end
      end
    end
  end
end
