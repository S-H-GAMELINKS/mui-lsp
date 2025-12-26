# frozen_string_literal: true

require "test_helper"

class TestTypeDefinitionHandler < Minitest::Test
  def setup
    @editor = MockEditor.new
    @client = MockClient.new
    @handler = Mui::Lsp::Handlers::TypeDefinition.new(editor: @editor, client: @client)
  end

  class TestHandleResult < TestTypeDefinitionHandler
    def test_handle_result_with_single_location
      result = {
        "uri" => "file:///path/to/types.rbs",
        "range" => {
          "start" => { "line" => 10, "character" => 0 },
          "end" => { "line" => 10, "character" => 10 }
        }
      }

      @handler.handle(result, nil)

      # Should jump directly without picker
      refute @editor.scratch_buffer_opened
      assert_equal 10, @editor.jumped_to_line
    end

    def test_handle_result_with_location_array
      result = [
        {
          "uri" => "file:///path/to/types.rbs",
          "range" => {
            "start" => { "line" => 5, "character" => 0 },
            "end" => { "line" => 5, "character" => 10 }
          }
        }
      ]

      @handler.handle(result, nil)

      # Single location - should jump directly
      refute @editor.scratch_buffer_opened
      assert_equal 5, @editor.jumped_to_line
    end

    def test_handle_result_with_multiple_locations
      result = [
        {
          "uri" => "file:///path/to/types1.rbs",
          "range" => {
            "start" => { "line" => 10, "character" => 0 },
            "end" => { "line" => 10, "character" => 10 }
          }
        },
        {
          "uri" => "file:///path/to/types2.rbs",
          "range" => {
            "start" => { "line" => 20, "character" => 0 },
            "end" => { "line" => 20, "character" => 10 }
          }
        }
      ]

      @handler.handle(result, nil)

      # Should open picker
      assert @editor.scratch_buffer_opened
      assert_equal "[LSP Picker]", @editor.scratch_buffer_name
      assert_includes @editor.scratch_buffer_content, "Type Definitions"
      assert_includes @editor.scratch_buffer_content, "types1.rbs:11"
      assert_includes @editor.scratch_buffer_content, "types2.rbs:21"
    end

    def test_handle_result_with_location_link
      result = [
        {
          "targetUri" => "file:///path/to/types.rbs",
          "targetRange" => {
            "start" => { "line" => 15, "character" => 0 },
            "end" => { "line" => 15, "character" => 10 }
          },
          "targetSelectionRange" => {
            "start" => { "line" => 15, "character" => 2 },
            "end" => { "line" => 15, "character" => 8 }
          }
        }
      ]

      @handler.handle(result, nil)

      # Should use targetSelectionRange for position
      assert_equal 15, @editor.jumped_to_line
      assert_equal 2, @editor.jumped_to_character
    end

    def test_handle_result_with_empty_result
      @handler.handle([], nil)

      assert_equal "No type definition found", @editor.message
    end

    def test_handle_result_with_nil
      @handler.handle(nil, nil)

      assert_equal "No type definition found", @editor.message
    end

    def test_stores_locations_for_picker
      result = [
        {
          "uri" => "file:///path/to/types1.rbs",
          "range" => {
            "start" => { "line" => 10, "character" => 0 },
            "end" => { "line" => 10, "character" => 10 }
          }
        },
        {
          "uri" => "file:///path/to/types2.rbs",
          "range" => {
            "start" => { "line" => 20, "character" => 0 },
            "end" => { "line" => 20, "character" => 10 }
          }
        }
      ]

      @handler.handle(result, nil)

      locations = @editor.instance_variable_get(:@lsp_picker_locations)
      assert_equal 2, locations.length
      assert_equal :type_definition, @editor.instance_variable_get(:@lsp_picker_type)
    end
  end

  class TestHandleError < TestTypeDefinitionHandler
    def test_handle_error_shows_message
      error = { "code" => -32_600, "message" => "Invalid request" }

      @handler.handle(nil, error)

      assert_match(/LSP Error/, @editor.message)
      assert_match(/Invalid request/, @editor.message)
    end
  end

  # Mock classes for testing
  class MockEditor
    attr_accessor :message, :scratch_buffer_opened, :scratch_buffer_name, :scratch_buffer_content,
                  :jumped_to_line, :jumped_to_character

    def initialize
      @message = nil
      @scratch_buffer_opened = false
      @scratch_buffer_name = nil
      @scratch_buffer_content = nil
      @jumped_to_line = nil
      @jumped_to_character = nil
      @current_buffer = MockBuffer.new
    end

    def open_scratch_buffer(name, content)
      @scratch_buffer_opened = true
      @scratch_buffer_name = name
      @scratch_buffer_content = content
    end

    def buffer
      @current_buffer
    end

    def window
      @window ||= MockWindow.new(self)
    end
  end

  class MockWindow
    attr_accessor :buffer
    attr_reader :cursor_row, :cursor_col

    def initialize(editor)
      @editor = editor
      @cursor_row = 0
      @cursor_col = 0
      @buffer = editor.buffer
    end

    def cursor_row=(line)
      @cursor_row = line
      @editor.jumped_to_line = line
    end

    def cursor_col=(char)
      @cursor_col = char
      @editor.jumped_to_character = char
    end

    def ensure_cursor_visible
      # No-op
    end
  end

  class MockBuffer
    def file_path
      "/path/to/current.rb"
    end
  end

  # Empty mock for type checking
  class MockClient; end # rubocop:disable Lint/EmptyClass
end
