# frozen_string_literal: true

require "uri"

module Mui
  module Lsp
    module Protocol
      # LSP Location (URI and range)
      class Location
        attr_accessor :uri, :range

        def initialize(uri:, range:)
          @uri = uri
          @range = range.is_a?(Range) ? range : Range.from_hash(range)
        end

        def to_h
          { uri: @uri, range: @range.to_h }
        end

        def self.from_hash(hash)
          new(
            uri: hash["uri"] || hash[:uri],
            range: hash["range"] || hash[:range]
          )
        end

        def file_path
          return nil unless @uri&.start_with?("file://")

          URI.decode_www_form_component(@uri.sub("file://", ""))
        end

        def ==(other)
          return false unless other.is_a?(Location)

          @uri == other.uri && @range == other.range
        end
      end
    end
  end
end
