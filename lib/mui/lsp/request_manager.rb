# frozen_string_literal: true

module Mui
  module Lsp
    # Manages pending JSON-RPC requests and their callbacks
    class RequestManager
      def initialize
        @next_id = 1
        @pending_requests = {}
        @mutex = Mutex.new
      end

      def register(callback)
        @mutex.synchronize do
          id = @next_id
          @next_id += 1
          @pending_requests[id] = {
            callback: callback,
            registered_at: Time.now
          }
          id
        end
      end

      def handle_response(id, result: nil, error: nil)
        request = @mutex.synchronize { @pending_requests.delete(id) }
        return false unless request

        if error
          request[:callback].call(nil, error)
        else
          request[:callback].call(result, nil)
        end
        true
      end

      def pending?(id)
        @mutex.synchronize { @pending_requests.key?(id) }
      end

      def pending_count
        @mutex.synchronize { @pending_requests.size }
      end

      def cancel(id)
        @mutex.synchronize { !@pending_requests.delete(id).nil? }
      end

      def cancel_all
        @mutex.synchronize { @pending_requests.clear }
      end

      def cleanup_stale(timeout_seconds)
        now = Time.now
        timed_out = []

        @mutex.synchronize do
          @pending_requests.each do |id, request|
            timed_out << id if now - request[:registered_at] > timeout_seconds
          end

          timed_out.each do |id|
            request = @pending_requests.delete(id)
            request[:callback]&.call(nil, { "code" => -32_603, "message" => "Request timed out" })
          end
        end

        timed_out
      end
    end
  end
end
