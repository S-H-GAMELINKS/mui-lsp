# frozen_string_literal: true

module Mui
  module Lsp
    # Manages text document synchronization with LSP server
    # Handles didOpen, didChange, didSave, didClose notifications
    # with debouncing support for change notifications
    class TextDocumentSync
      DEFAULT_DEBOUNCE_MS = 300

      def initialize(client:, server_config:, debounce_ms: DEFAULT_DEBOUNCE_MS)
        @client = client
        @server_config = server_config
        @debounce_ms = debounce_ms
        @open_documents = {}
        @pending_changes = {}
        @debounce_timers = {}
        @mutex = Mutex.new
      end

      def did_open(uri:, text:)
        file_path = uri_to_path(uri)
        language_id = @server_config.language_id_for(file_path)

        @mutex.synchronize do
          @open_documents[uri] = {
            version: 1,
            text: text,
            language_id: language_id
          }
        end

        @client.did_open(
          uri: uri,
          language_id: language_id,
          version: 1,
          text: text
        )
      end

      def did_change(uri:, text:, debounce: true)
        # Skip if sync_on_change is disabled for this server
        return unless @server_config.sync_on_change

        @mutex.synchronize do
          return unless @open_documents.key?(uri)

          @open_documents[uri][:version] += 1
          @open_documents[uri][:text] = text
          @pending_changes[uri] = text
        end

        if debounce
          schedule_debounced_change(uri)
        else
          flush_change(uri)
        end
      end

      def did_save(uri:, text: nil)
        # Flush any pending changes first
        flush_change(uri)
        @client.did_save(uri: uri, text: text)
      end

      def did_close(uri:)
        cancel_debounce_timer(uri)

        @mutex.synchronize do
          @open_documents.delete(uri)
          @pending_changes.delete(uri)
        end

        @client.did_close(uri: uri)
      end

      def open?(uri)
        @mutex.synchronize { @open_documents.key?(uri) }
      end

      def version(uri)
        @mutex.synchronize { @open_documents.dig(uri, :version) }
      end

      def flush_all
        uris = @mutex.synchronize { @pending_changes.keys.dup }
        uris.each { |uri| flush_change(uri) }
      end

      def close_all
        uris = @mutex.synchronize { @open_documents.keys.dup }
        uris.each { |uri| did_close(uri: uri) }
      end

      def self.path_to_uri(path)
        "file://#{File.expand_path(path)}"
      end

      def self.uri_to_path(uri)
        return nil unless uri&.start_with?("file://")

        URI.decode_www_form_component(uri.sub("file://", ""))
      end

      private

      def uri_to_path(uri)
        self.class.uri_to_path(uri)
      end

      def schedule_debounced_change(uri)
        cancel_debounce_timer(uri)

        timer = Thread.new do
          sleep(@debounce_ms / 1000.0)
          flush_change(uri)
        end

        @mutex.synchronize { @debounce_timers[uri] = timer }
      end

      def cancel_debounce_timer(uri)
        timer = @mutex.synchronize { @debounce_timers.delete(uri) }
        timer&.kill
      end

      def flush_change(uri)
        cancel_debounce_timer(uri)

        doc_info = nil
        text = nil

        @mutex.synchronize do
          text = @pending_changes.delete(uri)
          doc_info = @open_documents[uri]
        end

        return unless text && doc_info

        # Send full document sync (TextDocumentSyncKind.Full = 1)
        @client.did_change(
          uri: uri,
          version: doc_info[:version],
          changes: [{ text: text }]
        )
      end
    end
  end
end
