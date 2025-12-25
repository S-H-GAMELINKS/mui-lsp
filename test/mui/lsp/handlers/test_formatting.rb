# frozen_string_literal: true

require "test_helper"

class TestFormattingHandler < Minitest::Test
  def setup
    @editor = MockEditor.new
    @client = MockClient.new
    @handler = Mui::Lsp::Handlers::Formatting.new(editor: @editor, client: @client)
  end

  class TestHandleResult < TestFormattingHandler
    def test_handle_result_with_single_edit
      result = [
        {
          "range" => {
            "start" => { "line" => 0, "character" => 0 },
            "end" => { "line" => 0, "character" => 5 }
          },
          "newText" => "hello"
        }
      ]

      @handler.handle(result, nil)

      assert_match(/Formatted/, @editor.message)
      assert_match(/1 change/, @editor.message)
    end

    def test_handle_result_with_multiple_edits
      result = [
        {
          "range" => {
            "start" => { "line" => 0, "character" => 0 },
            "end" => { "line" => 0, "character" => 5 }
          },
          "newText" => "hello"
        },
        {
          "range" => {
            "start" => { "line" => 1, "character" => 0 },
            "end" => { "line" => 1, "character" => 5 }
          },
          "newText" => "world"
        }
      ]

      @handler.handle(result, nil)

      assert_match(/Formatted/, @editor.message)
      assert_match(/2 changes/, @editor.message)
    end

    def test_handle_result_with_empty_result
      @handler.handle([], nil)

      assert_equal "No formatting changes", @editor.message
    end

    def test_handle_result_with_nil
      @handler.handle(nil, nil)

      assert_equal "No formatting changes", @editor.message
    end

    def test_applies_edits_in_reverse_order
      # Set up buffer with initial content
      @editor.buffer.lines = %w[aaa bbb ccc]

      result = [
        {
          "range" => {
            "start" => { "line" => 0, "character" => 0 },
            "end" => { "line" => 0, "character" => 3 }
          },
          "newText" => "AAA"
        },
        {
          "range" => {
            "start" => { "line" => 2, "character" => 0 },
            "end" => { "line" => 2, "character" => 3 }
          },
          "newText" => "CCC"
        }
      ]

      @handler.handle(result, nil)

      # Both edits should be applied
      lines = @editor.buffer.lines
      assert_equal "AAA", lines[0]
      assert_equal "CCC", lines[2]
    end
  end

  class TestHandleError < TestFormattingHandler
    def test_handle_error_shows_message
      error = { "code" => -32_600, "message" => "Invalid request" }

      @handler.handle(nil, error)

      assert_match(/LSP Error/, @editor.message)
      assert_match(/Invalid request/, @editor.message)
    end
  end

  # Mock classes for testing
  class MockEditor
    attr_accessor :message, :buffer

    def initialize
      @message = nil
      @buffer = MockBuffer.new
    end

    def window
      @window ||= MockWindow.new
    end
  end

  class MockWindow
    attr_accessor :cursor_row, :cursor_col

    def initialize
      @cursor_row = 0
      @cursor_col = 0
    end
  end

  class MockBuffer
    attr_accessor :lines

    def initialize
      @lines = %w[hello world test]
    end

    def line(line_num)
      @lines[line_num]
    end

    def delete_line(line_num)
      @lines.delete_at(line_num) if line_num < @lines.length
    end

    def insert_line(line_num, content)
      @lines.insert(line_num, content)
    end

    def file_path
      "/path/to/file.rb"
    end
  end

  # Empty mock for type checking
  class MockClient; end # rubocop:disable Lint/EmptyClass
end
