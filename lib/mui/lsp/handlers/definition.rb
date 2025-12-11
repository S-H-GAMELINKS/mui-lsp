# frozen_string_literal: true

module Mui
  module Lsp
    module Handlers
      # Handler for textDocument/definition responses
      class Definition < Base
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
          @editor.message = "No definition found"
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
          # Show a list of locations for the user to choose from
          items = locations.map do |loc|
            file_path = loc.file_path || loc.uri
            line = loc.range.start.line + 1
            "#{file_path}:#{line}"
          end

          @editor.message = "Found #{locations.length} definitions: #{items.first}..."
          # TODO: Integrate with quickfix list or popup menu when available
        end
      end
    end
  end
end
