# frozen_string_literal: true

require_relative "../../test_helper"

class TestProtocol < Minitest::Test
  def test_position_initialization
    pos = Mui::Lsp::Protocol::Position.new(line: 10, character: 5)
    assert_equal 10, pos.line
    assert_equal 5, pos.character
  end

  def test_position_to_h
    pos = Mui::Lsp::Protocol::Position.new(line: 10, character: 5)
    assert_equal({ line: 10, character: 5 }, pos.to_h)
  end

  def test_position_from_hash
    pos = Mui::Lsp::Protocol::Position.from_hash({ "line" => 10, "character" => 5 })
    assert_equal 10, pos.line
    assert_equal 5, pos.character
  end

  def test_position_equality
    pos1 = Mui::Lsp::Protocol::Position.new(line: 10, character: 5)
    pos2 = Mui::Lsp::Protocol::Position.new(line: 10, character: 5)
    pos3 = Mui::Lsp::Protocol::Position.new(line: 10, character: 6)

    assert_equal pos1, pos2
    refute_equal pos1, pos3
  end

  def test_range_initialization
    start_pos = Mui::Lsp::Protocol::Position.new(line: 0, character: 0)
    end_pos = Mui::Lsp::Protocol::Position.new(line: 0, character: 10)
    range = Mui::Lsp::Protocol::Range.new(start: start_pos, end_pos: end_pos)

    assert_equal start_pos, range.start
    assert_equal end_pos, range.end
  end

  def test_range_from_hash
    range = Mui::Lsp::Protocol::Range.from_hash({
                                                  "start" => { "line" => 0, "character" => 0 },
                                                  "end" => { "line" => 0, "character" => 10 }
                                                })

    assert_equal 0, range.start.line
    assert_equal 0, range.start.character
    assert_equal 0, range.end.line
    assert_equal 10, range.end.character
  end

  def test_location_initialization
    range = Mui::Lsp::Protocol::Range.new(
      start: Mui::Lsp::Protocol::Position.new(line: 0, character: 0),
      end_pos: Mui::Lsp::Protocol::Position.new(line: 0, character: 10)
    )
    loc = Mui::Lsp::Protocol::Location.new(uri: "file:///test.rb", range: range)

    assert_equal "file:///test.rb", loc.uri
    assert_equal range, loc.range
  end

  def test_location_file_path
    range = Mui::Lsp::Protocol::Range.new(
      start: Mui::Lsp::Protocol::Position.new(line: 0, character: 0),
      end_pos: Mui::Lsp::Protocol::Position.new(line: 0, character: 10)
    )
    loc = Mui::Lsp::Protocol::Location.new(uri: "file:///home/user/test.rb", range: range)

    assert_equal "/home/user/test.rb", loc.file_path
  end

  def test_location_file_path_non_file_uri
    range = Mui::Lsp::Protocol::Range.new(
      start: Mui::Lsp::Protocol::Position.new(line: 0, character: 0),
      end_pos: Mui::Lsp::Protocol::Position.new(line: 0, character: 10)
    )
    loc = Mui::Lsp::Protocol::Location.new(uri: "https://example.com", range: range)

    assert_nil loc.file_path
  end

  def test_diagnostic_initialization
    range = Mui::Lsp::Protocol::Range.new(
      start: Mui::Lsp::Protocol::Position.new(line: 5, character: 0),
      end_pos: Mui::Lsp::Protocol::Position.new(line: 5, character: 20)
    )
    diag = Mui::Lsp::Protocol::Diagnostic.new(
      range: range,
      message: "Undefined variable",
      severity: Mui::Lsp::Protocol::DiagnosticSeverity::ERROR,
      source: "rubocop"
    )

    assert_equal range, diag.range
    assert_equal "Undefined variable", diag.message
    assert_equal 1, diag.severity
    assert_equal "rubocop", diag.source
  end

  def test_diagnostic_severity_helpers
    range = Mui::Lsp::Protocol::Range.new(
      start: Mui::Lsp::Protocol::Position.new(line: 0, character: 0),
      end_pos: Mui::Lsp::Protocol::Position.new(line: 0, character: 10)
    )

    error = Mui::Lsp::Protocol::Diagnostic.new(
      range: range,
      message: "Error",
      severity: Mui::Lsp::Protocol::DiagnosticSeverity::ERROR
    )
    warning = Mui::Lsp::Protocol::Diagnostic.new(
      range: range,
      message: "Warning",
      severity: Mui::Lsp::Protocol::DiagnosticSeverity::WARNING
    )

    assert error.error?
    refute error.warning?
    refute warning.error?
    assert warning.warning?
  end

  def test_diagnostic_severity_name
    range = Mui::Lsp::Protocol::Range.new(
      start: Mui::Lsp::Protocol::Position.new(line: 0, character: 0),
      end_pos: Mui::Lsp::Protocol::Position.new(line: 0, character: 10)
    )

    error = Mui::Lsp::Protocol::Diagnostic.new(
      range: range,
      message: "Error",
      severity: Mui::Lsp::Protocol::DiagnosticSeverity::ERROR
    )

    assert_equal "Error", error.severity_name
  end
end
