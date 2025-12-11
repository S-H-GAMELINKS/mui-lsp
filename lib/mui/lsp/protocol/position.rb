# frozen_string_literal: true

module Mui
  module Lsp
    module Protocol
      # LSP Position (0-indexed line and character)
      class Position
        attr_accessor :line, :character

        def initialize(line:, character:)
          @line = line
          @character = character
        end

        def to_h
          { line: @line, character: @character }
        end

        def self.from_hash(hash)
          new(line: hash["line"] || hash[:line], character: hash["character"] || hash[:character])
        end

        def ==(other)
          return false unless other.is_a?(Position)

          @line == other.line && @character == other.character
        end
      end
    end
  end
end
