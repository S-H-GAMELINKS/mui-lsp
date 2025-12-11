# frozen_string_literal: true

module Mui
  module Lsp
    module Highlighters
      # Highlighter for LSP diagnostics (errors, warnings, etc.)
      class DiagnosticHighlighter < Mui::Highlighters::Base
        PRIORITY_DIAGNOSTICS = 250 # Between selection and search

        def initialize(color_scheme, diagnostics)
          super(color_scheme)
          @diagnostics = diagnostics
        end

        def highlights_for(row, line, _options = {})
          highlights = []

          @diagnostics.each do |d|
            next unless row.between?(d.range.start.line, d.range.end.line)

            start_col = d.range.start.line == row ? d.range.start.character : 0
            end_col = if d.range.end.line == row
                        d.range.end.character
                      else
                        line.length
                      end

            # Ensure end_col is at least start_col + 1
            end_col = [end_col, start_col + 1].max

            style = severity_style(d.severity)
            highlights << Mui::Highlight.new(
              start_col: start_col,
              end_col: end_col,
              style: style,
              priority: priority
            )
          end

          highlights
        end

        def priority
          PRIORITY_DIAGNOSTICS
        end

        # Update diagnostics (called when new diagnostics arrive)
        def update(diagnostics)
          @diagnostics = diagnostics
        end

        private

        def severity_style(severity)
          case severity
          when Protocol::DiagnosticSeverity::ERROR
            :diagnostic_error
          when Protocol::DiagnosticSeverity::WARNING
            :diagnostic_warning
          when Protocol::DiagnosticSeverity::INFORMATION
            :diagnostic_info
          when Protocol::DiagnosticSeverity::HINT
            :diagnostic_hint
          else
            :diagnostic_error
          end
        end
      end
    end
  end
end
