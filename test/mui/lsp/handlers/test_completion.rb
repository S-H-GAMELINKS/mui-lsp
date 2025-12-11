# frozen_string_literal: true

require "test_helper"

class TestCompletionHandler < Minitest::Test
  def setup
    @editor = MockEditor.new
    @client = MockClient.new
    @handler = Mui::Lsp::Handlers::Completion.new(editor: @editor, client: @client)
  end

  class TestHandleResult < TestCompletionHandler
    def test_handle_result_with_array_of_items
      items = [
        { "label" => "method1", "kind" => 2, "insertText" => "method1()" },
        { "label" => "method2", "kind" => 2 }
      ]

      @handler.handle(items, nil)

      assert @editor.completion_started
      assert_equal 2, @editor.completion_items.length
      assert_equal "method1", @editor.completion_items[0][:label]
      assert_equal "method1()", @editor.completion_items[0][:insert_text]
    end

    def test_handle_result_with_completion_list
      result = {
        "isIncomplete" => false,
        "items" => [
          { "label" => "foo", "kind" => 6 },
          { "label" => "bar", "kind" => 6 }
        ]
      }

      @handler.handle(result, nil)

      assert @editor.completion_started
      assert_equal 2, @editor.completion_items.length
    end

    def test_handle_result_with_empty_items
      @handler.handle([], nil)

      refute @editor.completion_started
      assert_equal "No completions available", @editor.message
    end

    def test_handle_result_with_text_edit
      items = [
        {
          "label" => "user",
          "kind" => 6,
          "textEdit" => {
            "range" => {
              "start" => { "line" => 0, "character" => 0 },
              "end" => { "line" => 0, "character" => 5 }
            },
            "newText" => "@user"
          }
        }
      ]

      @handler.handle(items, nil)

      assert @editor.completion_started
      assert_equal "@user", @editor.completion_items[0][:text_edit]["newText"]
    end

    def test_handle_result_sorts_by_sort_text
      items = [
        { "label" => "zebra", "kind" => 6, "sortText" => "2" },
        { "label" => "alpha", "kind" => 6, "sortText" => "1" }
      ]

      @handler.handle(items, nil)

      assert @editor.completion_started
      assert_equal "alpha", @editor.completion_items[0][:label]
      assert_equal "zebra", @editor.completion_items[1][:label]
    end

    def test_handle_result_uses_insert_text_when_present
      items = [
        { "label" => "display_name", "kind" => 2, "insertText" => "actual_insert_text" }
      ]

      @handler.handle(items, nil)

      assert_equal "display_name", @editor.completion_items[0][:label]
      assert_equal "actual_insert_text", @editor.completion_items[0][:insert_text]
    end

    def test_handle_result_falls_back_to_label_for_insert_text
      items = [
        { "label" => "method_name", "kind" => 2 }
      ]

      @handler.handle(items, nil)

      assert_equal "method_name", @editor.completion_items[0][:insert_text]
    end
  end

  class TestHandleError < TestCompletionHandler
    def test_handle_error_shows_message
      error = { "code" => -32600, "message" => "Invalid request" }

      @handler.handle(nil, error)

      assert_match(/LSP Error/, @editor.message)
      assert_match(/Invalid request/, @editor.message)
    end
  end

  class TestKindConstants < TestCompletionHandler
    def test_kind_constants_defined
      assert_equal 1, Mui::Lsp::Handlers::Completion::Kind::TEXT
      assert_equal 2, Mui::Lsp::Handlers::Completion::Kind::METHOD
      assert_equal 3, Mui::Lsp::Handlers::Completion::Kind::FUNCTION
      assert_equal 6, Mui::Lsp::Handlers::Completion::Kind::VARIABLE
      assert_equal 7, Mui::Lsp::Handlers::Completion::Kind::CLASS
      assert_equal 9, Mui::Lsp::Handlers::Completion::Kind::MODULE
      assert_equal 14, Mui::Lsp::Handlers::Completion::Kind::KEYWORD
    end
  end

  # Mock classes for testing
  class MockEditor
    attr_accessor :message, :completion_started, :completion_items, :completion_prefix

    def initialize
      @message = nil
      @completion_started = false
      @completion_items = []
      @completion_prefix = ""
    end

    def start_insert_completion(items, prefix: "")
      @completion_started = true
      @completion_items = items
      @completion_prefix = prefix
    end

    def respond_to?(method)
      method == :start_insert_completion || super
    end

    def window
      MockWindow.new
    end
  end

  class MockWindow
    def cursor_row
      0
    end

    def cursor_col
      5
    end

    def buffer
      MockBuffer.new
    end
  end

  class MockBuffer
    def line(_row)
      "hello"
    end
  end

  class MockClient
  end
end
