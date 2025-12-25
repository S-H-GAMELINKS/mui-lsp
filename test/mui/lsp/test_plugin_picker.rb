# frozen_string_literal: true

require "test_helper"

class TestPluginPicker < Minitest::Test
  def setup
    @plugin = Mui::Lsp::Plugin.new
  end

  class TestPickerActive < TestPluginPicker
    def test_picker_active_returns_true_for_picker_buffer
      editor = MockEditor.new("[LSP Picker]")
      assert @plugin.send(:picker_active?, editor)
    end

    def test_picker_active_returns_false_for_normal_buffer
      editor = MockEditor.new("/path/to/file.rb")
      refute @plugin.send(:picker_active?, editor)
    end

    def test_picker_active_returns_false_for_nil_buffer
      editor = MockEditor.new(nil)
      refute @plugin.send(:picker_active?, editor)
    end
  end

  class TestClosePicker < TestPluginPicker
    def test_close_picker_clears_instance_variables
      editor = MockEditor.new("[LSP Picker]")
      editor.instance_variable_set(:@lsp_picker_locations, [create_location])
      editor.instance_variable_set(:@lsp_picker_type, :definition)

      @plugin.send(:close_picker, editor)

      assert_nil editor.instance_variable_get(:@lsp_picker_locations)
      assert_nil editor.instance_variable_get(:@lsp_picker_type)
    end

    def test_close_picker_calls_close_current_window
      editor = MockEditor.new("[LSP Picker]")
      editor.instance_variable_set(:@lsp_picker_locations, [create_location])

      @plugin.send(:close_picker, editor)

      assert editor.window_manager.close_called
    end
  end

  private

  def create_location
    Mui::Lsp::Protocol::Location.new(
      uri: "file:///path/to/file.rb",
      range: {
        "start" => { "line" => 10, "character" => 0 },
        "end" => { "line" => 10, "character" => 10 }
      }
    )
  end

  # Mock classes for testing
  class MockEditor
    attr_reader :window_manager, :buffer

    def initialize(file_path)
      @buffer = MockBuffer.new(file_path)
      @window_manager = MockWindowManager.new
    end
  end

  class MockBuffer
    attr_reader :file_path

    def initialize(file_path)
      @file_path = file_path
    end
  end

  class MockWindowManager
    attr_reader :close_called

    def initialize
      @close_called = false
    end

    def close_current_window
      @close_called = true
    end
  end
end
