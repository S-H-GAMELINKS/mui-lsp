# frozen_string_literal: true

require_relative "../../../test_helper"

class TestDiagnosticHighlighter < Minitest::Test
  class MockColorScheme
    def [](_key)
      { fg: :red, underline: true }
    end
  end

  def setup
    @color_scheme = MockColorScheme.new
  end

  def create_diagnostic(start_line:, start_char:, end_line:, end_char:, severity: 1)
    {
      "range" => {
        "start" => { "line" => start_line, "character" => start_char },
        "end" => { "line" => end_line, "character" => end_char }
      },
      "severity" => severity,
      "message" => "Test diagnostic"
    }
  end

  def parse_diagnostic(hash)
    Mui::Lsp::Protocol::Diagnostic.from_hash(hash)
  end

  class TestHighlightsFor < TestDiagnosticHighlighter
    def test_returns_empty_array_when_no_diagnostics
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [])

      highlights = highlighter.highlights_for(0, "hello world")

      assert_empty highlights
    end

    def test_returns_highlight_for_single_line_diagnostic
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 0,
                                end_line: 0, end_char: 5
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(0, "hello world")

      assert_equal 1, highlights.length
      assert_equal 0, highlights.first.start_col
      assert_equal 5, highlights.first.end_col
    end

    def test_returns_empty_for_row_outside_diagnostic
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 5, start_char: 0,
                                end_line: 5, end_char: 5
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(0, "hello world")

      assert_empty highlights
    end

    def test_handles_multiline_diagnostic_start
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 3,
                                end_line: 2, end_char: 5
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(0, "hello world")

      assert_equal 1, highlights.length
      assert_equal 3, highlights.first.start_col
      # End extends to line length for multiline
      assert_equal 11, highlights.first.end_col
    end

    def test_handles_multiline_diagnostic_middle
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 3,
                                end_line: 2, end_char: 5
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(1, "middle line")

      assert_equal 1, highlights.length
      assert_equal 0, highlights.first.start_col
      assert_equal 11, highlights.first.end_col
    end

    def test_handles_multiline_diagnostic_end
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 3,
                                end_line: 2, end_char: 5
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(2, "end line")

      assert_equal 1, highlights.length
      assert_equal 0, highlights.first.start_col
      assert_equal 5, highlights.first.end_col
    end

    def test_ensures_minimum_highlight_width
      # Zero-width diagnostic (same start and end position)
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 5,
                                end_line: 0, end_char: 5
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(0, "hello world")

      assert_equal 1, highlights.length
      # end_col should be at least start_col + 1
      assert_equal 5, highlights.first.start_col
      assert_equal 6, highlights.first.end_col
    end
  end

  class TestSeverityStyle < TestDiagnosticHighlighter
    def test_error_severity_returns_diagnostic_error_style
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 0,
                                end_line: 0, end_char: 5,
                                severity: Mui::Lsp::Protocol::DiagnosticSeverity::ERROR
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(0, "hello")

      assert_equal :diagnostic_error, highlights.first.style
    end

    def test_warning_severity_returns_diagnostic_warning_style
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 0,
                                end_line: 0, end_char: 5,
                                severity: Mui::Lsp::Protocol::DiagnosticSeverity::WARNING
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(0, "hello")

      assert_equal :diagnostic_warning, highlights.first.style
    end

    def test_info_severity_returns_diagnostic_info_style
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 0,
                                end_line: 0, end_char: 5,
                                severity: Mui::Lsp::Protocol::DiagnosticSeverity::INFORMATION
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(0, "hello")

      assert_equal :diagnostic_info, highlights.first.style
    end

    def test_hint_severity_returns_diagnostic_hint_style
      diag = parse_diagnostic(create_diagnostic(
                                start_line: 0, start_char: 0,
                                end_line: 0, end_char: 5,
                                severity: Mui::Lsp::Protocol::DiagnosticSeverity::HINT
                              ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag])

      highlights = highlighter.highlights_for(0, "hello")

      assert_equal :diagnostic_hint, highlights.first.style
    end
  end

  class TestUpdate < TestDiagnosticHighlighter
    def test_update_replaces_diagnostics
      diag1 = parse_diagnostic(create_diagnostic(
                                 start_line: 0, start_char: 0,
                                 end_line: 0, end_char: 5
                               ))
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [diag1])

      diag2 = parse_diagnostic(create_diagnostic(
                                 start_line: 1, start_char: 0,
                                 end_line: 1, end_char: 3
                               ))
      highlighter.update([diag2])

      # Old diagnostic should not highlight
      assert_empty highlighter.highlights_for(0, "hello")
      # New diagnostic should highlight
      refute_empty highlighter.highlights_for(1, "world")
    end
  end

  class TestPriority < TestDiagnosticHighlighter
    def test_has_diagnostic_priority
      highlighter = Mui::Lsp::Highlighters::DiagnosticHighlighter.new(@color_scheme, [])

      assert_equal 250, highlighter.priority
    end
  end
end
