# frozen_string_literal: true

module Mui
  module Lsp
    module Protocol
      # LSP DiagnosticSeverity constants
      module DiagnosticSeverity
        ERROR = 1
        WARNING = 2
        INFORMATION = 3
        HINT = 4
      end

      # LSP Diagnostic (error/warning/info/hint message)
      class Diagnostic
        attr_accessor :range, :severity, :code, :source, :message, :related_information

        def initialize(range:, message:, severity: nil, code: nil, source: nil, related_information: nil)
          @range = range.is_a?(Range) ? range : Range.from_hash(range)
          @message = message
          @severity = severity
          @code = code
          @source = source
          @related_information = related_information
        end

        def to_h
          result = {
            range: @range.to_h,
            message: @message
          }
          result[:severity] = @severity if @severity
          result[:code] = @code if @code
          result[:source] = @source if @source
          result[:relatedInformation] = @related_information if @related_information
          result
        end

        def self.from_hash(hash)
          new(
            range: hash["range"] || hash[:range],
            message: hash["message"] || hash[:message],
            severity: hash["severity"] || hash[:severity],
            code: hash["code"] || hash[:code],
            source: hash["source"] || hash[:source],
            related_information: hash["relatedInformation"] || hash[:relatedInformation]
          )
        end

        def error?
          @severity == DiagnosticSeverity::ERROR
        end

        def warning?
          @severity == DiagnosticSeverity::WARNING
        end

        def information?
          @severity == DiagnosticSeverity::INFORMATION
        end

        def hint?
          @severity == DiagnosticSeverity::HINT
        end

        def severity_name
          case @severity
          when DiagnosticSeverity::ERROR then "Error"
          when DiagnosticSeverity::WARNING then "Warning"
          when DiagnosticSeverity::INFORMATION then "Information"
          when DiagnosticSeverity::HINT then "Hint"
          else "Unknown"
          end
        end

        def ==(other)
          return false unless other.is_a?(Diagnostic)

          @range == other.range &&
            @message == other.message &&
            @severity == other.severity &&
            @code == other.code &&
            @source == other.source
        end
      end
    end
  end
end
