# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Mock Mui module for tests
module Mui
  class Plugin
    def self.name(_name = nil)
      # No-op
    end
  end

  class << self
    def plugin_manager
      @plugin_manager ||= MockPluginManager.new
    end
  end

  class MockPluginManager
    def register(_name, _klass)
      # No-op
    end
  end

  # Mock Highlighters module
  module Highlighters
    class Base
      def initialize(color_scheme)
        @color_scheme = color_scheme
      end
    end
  end

  # Mock Highlight class
  class Highlight
    attr_reader :start_col, :end_col, :style, :priority

    def initialize(start_col:, end_col:, style:, priority:)
      @start_col = start_col
      @end_col = end_col
      @style = style
      @priority = priority
    end
  end
end

require "mui/lsp"

require "minitest/autorun"
