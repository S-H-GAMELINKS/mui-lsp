# frozen_string_literal: true

module Mui
  module Lsp
    module Handlers
      # Handler for textDocument/publishDiagnostics notifications
      class Diagnostics
        attr_reader :editor, :diagnostics_by_uri

        def initialize(editor:)
          @editor = editor
          @diagnostics_by_uri = {}
          @mutex = Mutex.new
        end

        def handle(params)
          uri = params["uri"]
          raw_diagnostics = params["diagnostics"] || []

          diagnostics = raw_diagnostics.map do |d|
            Protocol::Diagnostic.from_hash(d)
          end

          @mutex.synchronize do
            if diagnostics.empty?
              @diagnostics_by_uri.delete(uri)
            else
              @diagnostics_by_uri[uri] = diagnostics
            end
          end

          update_display(uri, diagnostics)
        end

        def diagnostics_for(uri)
          @mutex.synchronize { @diagnostics_by_uri[uri] || [] }
        end

        def all_diagnostics
          @mutex.synchronize { @diagnostics_by_uri.dup }
        end

        def diagnostics_at_line(uri, line)
          diagnostics_for(uri).select do |d|
            line.between?(d.range.start.line, d.range.end.line)
          end
        end

        def clear_all
          @mutex.synchronize { @diagnostics_by_uri.clear }
        end

        def clear(uri)
          @mutex.synchronize { @diagnostics_by_uri.delete(uri) }
        end

        def counts(uri = nil)
          diagnostics = uri ? diagnostics_for(uri) : @mutex.synchronize { @diagnostics_by_uri.values.flatten }

          {
            error: diagnostics.count(&:error?),
            warning: diagnostics.count(&:warning?),
            information: diagnostics.count(&:information?),
            hint: diagnostics.count(&:hint?)
          }
        end

        def summary(uri = nil)
          c = counts(uri)
          parts = []
          parts << "E:#{c[:error]}" if c[:error].positive?
          parts << "W:#{c[:warning]}" if c[:warning].positive?
          parts << "I:#{c[:information]}" if c[:information].positive?
          parts << "H:#{c[:hint]}" if c[:hint].positive?
          parts.empty? ? "" : parts.join(" ")
        end

        private

        def update_display(uri, diagnostics)
          # Update message area with summary
          if diagnostics.empty?
            @editor.message = "Diagnostics cleared"
          else
            error_count = diagnostics.count(&:error?)
            warning_count = diagnostics.count(&:warning?)
            @editor.message = "#{diagnostics.length} diagnostics (#{error_count} errors, #{warning_count} warnings)"
          end

          # Apply custom highlighter if available
          apply_highlights(uri, diagnostics)
        end

        def apply_highlights(uri, diagnostics)
          file_path = TextDocumentSync.uri_to_path(uri)
          return unless file_path

          # Get current buffer and check if it matches
          buffer = @editor.buffer
          return unless buffer&.file_path

          # Compare paths - need to expand to handle relative vs absolute
          buffer_path = File.expand_path(buffer.file_path)
          diag_path = File.expand_path(file_path)
          return unless buffer_path == diag_path

          # Remove existing diagnostic highlighter
          had_highlighter = buffer.custom_highlighter?(:lsp_diagnostics)
          buffer.remove_custom_highlighter(:lsp_diagnostics)

          if diagnostics.empty?
            @editor.window&.refresh_highlighters if had_highlighter
            return
          end

          # Create and add new highlighter
          color_scheme = @editor.color_scheme
          highlighter = Highlighters::DiagnosticHighlighter.new(color_scheme, diagnostics)
          buffer.add_custom_highlighter(:lsp_diagnostics, highlighter)

          # Refresh window's highlighters to pick up the change
          @editor.window&.refresh_highlighters
        end

        def build_highlighter(diagnostics)
          # Return a lambda that highlights diagnostic ranges
          lambda do |line_index, line_content|
            highlights = []

            diagnostics.each do |d|
              next unless line_index.between?(d.range.start.line, d.range.end.line)

              start_col = d.range.start.line == line_index ? d.range.start.character : 0
              end_col = d.range.end.line == line_index ? d.range.end.character : line_content.length

              color = severity_color(d.severity)
              highlights << { start: start_col, end: end_col, color: color }
            end

            highlights
          end
        end

        def severity_color(severity)
          case severity
          when Protocol::DiagnosticSeverity::ERROR
            :red
          when Protocol::DiagnosticSeverity::WARNING
            :yellow
          when Protocol::DiagnosticSeverity::INFORMATION
            :blue
          when Protocol::DiagnosticSeverity::HINT
            :cyan
          else
            :default
          end
        end
      end
    end
  end
end
