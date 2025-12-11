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
          show_references(locations)
        end

        def handle_empty
          @editor.message = "No references found"
        end

        private

        def show_references(locations)
          count = locations.length

          # Build message with first few references
          lines = ["Found #{count} reference#{"s" unless count == 1}"]

          # Group by file for display
          by_file = locations.group_by(&:file_path)

          # Display first few references
          displayed = 0
          max_display = 3

          by_file.each do |file_path, file_locations|
            break if displayed >= max_display

            file_locations.each do |loc|
              break if displayed >= max_display

              line = loc.range.start.line + 1
              lines << "  #{file_path || loc.uri}:#{line}"
              displayed += 1
            end
          end

          lines << "  ... and #{count - max_display} more" if count > max_display

          @editor.message = lines.first

          # TODO: Integrate with quickfix list when available
          # Store references for navigation
          store_references(locations)
        end

        def store_references(locations)
          # Store references for potential :cnext/:cprev navigation
          # This could be integrated with Mui's quickfix system if available
          @editor.instance_variable_set(:@lsp_references, locations)
        end
      end
    end
  end
end
