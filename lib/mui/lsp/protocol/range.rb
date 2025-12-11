# frozen_string_literal: true

module Mui
  module Lsp
    module Protocol
      # LSP Range (start and end positions)
      class Range
        attr_accessor :start, :end

        def initialize(start:, end_pos:)
          @start = start.is_a?(Position) ? start : Position.from_hash(start)
          @end = end_pos.is_a?(Position) ? end_pos : Position.from_hash(end_pos)
        end

        def to_h
          { start: @start.to_h, end: @end.to_h }
        end

        def self.from_hash(hash)
          new(
            start: hash["start"] || hash[:start],
            end_pos: hash["end"] || hash[:end]
          )
        end

        def ==(other)
          return false unless other.is_a?(Range)

          @start == other.start && @end == other.end
        end
      end
    end
  end
end
