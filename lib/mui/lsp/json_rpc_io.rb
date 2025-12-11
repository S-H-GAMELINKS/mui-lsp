# frozen_string_literal: true

require "json"

module Mui
  module Lsp
    # JSON-RPC 2.0 over stdio communication handler
    # Handles LSP message framing with Content-Length headers
    class JsonRpcIO
      CONTENT_LENGTH_HEADER = "Content-Length:"
      HEADER_DELIMITER = "\r\n\r\n"

      attr_reader :input, :output

      def initialize(input:, output:)
        @input = input
        @output = output
        @mutex = Mutex.new
      end

      def read_message
        content_length = read_headers
        return nil if content_length.nil?

        body = @input.read(content_length)
        return nil if body.nil? || body.empty?

        JSON.parse(body)
      rescue JSON::ParserError => e
        raise Error, "Failed to parse JSON: #{e.message}"
      end

      def write_message(message)
        json = JSON.generate(message)
        content = "#{CONTENT_LENGTH_HEADER} #{json.bytesize}\r\n\r\n#{json}"

        @mutex.synchronize do
          @output.write(content)
          @output.flush
        end
        true
      rescue IOError, Errno::EPIPE
        # Pipe is broken, server probably exited
        false
      end

      def self.build_request(id:, method:, params: nil)
        message = {
          jsonrpc: "2.0",
          id: id,
          method: method
        }
        message[:params] = params if params
        message
      end

      def self.build_notification(method:, params: nil)
        message = {
          jsonrpc: "2.0",
          method: method
        }
        message[:params] = params if params
        message
      end

      def self.build_response(id:, result:)
        {
          jsonrpc: "2.0",
          id: id,
          result: result
        }
      end

      def self.build_error_response(id:, code:, message:, data: nil)
        error = {
          code: code,
          message: message
        }
        error[:data] = data if data

        {
          jsonrpc: "2.0",
          id: id,
          error: error
        }
      end

      def self.request?(message)
        message.key?("id") && message.key?("method")
      end

      def self.notification?(message)
        !message.key?("id") && message.key?("method")
      end

      def self.response?(message)
        message.key?("id") && !message.key?("method") && (message.key?("result") || message.key?("error"))
      end

      private

      def read_headers
        headers = {}
        loop do
          line = @input.gets("\r\n")
          return nil if line.nil?

          line = line.chomp("\r\n")
          break if line.empty?

          if line.start_with?(CONTENT_LENGTH_HEADER)
            headers[:content_length] = line.sub(CONTENT_LENGTH_HEADER, "").strip.to_i
          end
        end

        headers[:content_length]
      end
    end
  end
end
