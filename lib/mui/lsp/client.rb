# frozen_string_literal: true

require "open3"

module Mui
  module Lsp
    # LSP Client - manages connection to a language server
    class Client
      attr_reader :server_capabilities, :initialized, :root_uri, :last_stderr

      def initialize(command:, root_path:, on_notification: nil)
        @command = command
        @root_path = root_path
        @root_uri = "file://#{root_path}"
        @on_notification = on_notification
        @initialized = false
        @server_capabilities = {}
        @process = nil
        @io = nil
        @request_manager = RequestManager.new
        @reader_thread = nil
        @running = false
      end

      def start
        return if @running

        # Split command into array for proper shell handling
        cmd_parts = @command.is_a?(Array) ? @command : @command.split(/\s+/)
        stdin, stdout, stderr, @process = Open3.popen3(*cmd_parts)
        @io = JsonRpcIO.new(input: stdout, output: stdin)
        @stderr = stderr
        @running = true
        @init_mutex = Mutex.new
        @init_cv = ConditionVariable.new

        start_reader_thread
        start_stderr_thread
        initialize_server

        # Wait for initialization to complete (with timeout)
        @init_mutex.synchronize do
          unless @initialized
            @init_cv.wait(@init_mutex, 10) # 10 second timeout
          end
        end
      end

      def stop
        return unless @running

        @running = false
        shutdown
        @reader_thread&.join(2)
        begin
          @process&.kill
        rescue StandardError
          nil
        end
        @request_manager.cancel_all
      end

      def running?
        @running && @initialized
      end

      def started?
        @running
      end

      def request(method, params = nil, &callback)
        return nil unless @running

        id = @request_manager.register(callback)
        message = JsonRpcIO.build_request(id: id, method: method, params: params)
        unless @io.write_message(message)
          @running = false
          @request_manager.cancel(id)
          return nil
        end
        id
      end

      def notify(method, params = nil)
        return unless @running

        message = JsonRpcIO.build_notification(method: method, params: params)
        return if @io.write_message(message)

        @running = false
      end

      def hover(uri:, line:, character:, &callback)
        request("textDocument/hover", {
                  textDocument: { uri: uri },
                  position: { line: line, character: character }
                }, &callback)
      end

      def definition(uri:, line:, character:, &callback)
        request("textDocument/definition", {
                  textDocument: { uri: uri },
                  position: { line: line, character: character }
                }, &callback)
      end

      def type_definition(uri:, line:, character:, &callback)
        request("textDocument/typeDefinition", {
                  textDocument: { uri: uri },
                  position: { line: line, character: character }
                }, &callback)
      end

      def references(uri:, line:, character:, include_declaration: true, &callback)
        request("textDocument/references", {
                  textDocument: { uri: uri },
                  position: { line: line, character: character },
                  context: { includeDeclaration: include_declaration }
                }, &callback)
      end

      def completion(uri:, line:, character:, &callback)
        request("textDocument/completion", {
                  textDocument: { uri: uri },
                  position: { line: line, character: character }
                }, &callback)
      end

      def formatting(uri:, tab_size: 2, insert_spaces: true, &callback)
        request("textDocument/formatting", {
                  textDocument: { uri: uri },
                  options: {
                    tabSize: tab_size,
                    insertSpaces: insert_spaces
                  }
                }, &callback)
      end

      def did_open(uri:, language_id:, version:, text:)
        notify("textDocument/didOpen", {
                 textDocument: {
                   uri: uri,
                   languageId: language_id,
                   version: version,
                   text: text
                 }
               })
      end

      def did_change(uri:, version:, changes:)
        notify("textDocument/didChange", {
                 textDocument: { uri: uri, version: version },
                 contentChanges: changes
               })
      end

      def did_save(uri:, text: nil)
        params = { textDocument: { uri: uri } }
        params[:text] = text if text
        notify("textDocument/didSave", params)
      end

      def did_close(uri:)
        notify("textDocument/didClose", {
                 textDocument: { uri: uri }
               })
      end

      private

      def start_reader_thread
        @reader_thread = Thread.new do
          while @running
            begin
              message = @io.read_message
              break if message.nil?

              handle_message(message)
            rescue IOError, Errno::EPIPE
              # Pipe closed, server exited
              break
            rescue StandardError
              # Log error but continue reading
              break unless @running
            end
          end
        end
      end

      def start_stderr_thread
        @stderr_lines = []
        @stderr_thread = Thread.new do
          while @running
            begin
              line = @stderr.gets
              break if line.nil?

              # Store stderr for debugging
              @stderr_lines << line.chomp
              @last_stderr = @stderr_lines.last(10).join("\n")
            rescue IOError
              break
            end
          end
        end
      end

      def handle_message(message)
        if JsonRpcIO.response?(message)
          handle_response(message)
        elsif JsonRpcIO.notification?(message)
          handle_notification(message)
        elsif JsonRpcIO.request?(message)
          handle_server_request(message)
        end
      end

      def handle_response(message)
        id = message["id"]
        result = message["result"]
        error = message["error"]
        @request_manager.handle_response(id, result: result, error: error)
      end

      def handle_notification(message)
        @on_notification&.call(message["method"], message["params"])
      end

      def handle_server_request(message)
        # Handle server-initiated requests (e.g., workspace/configuration)
        id = message["id"]
        method = message["method"]

        response = JsonRpcIO.build_response(id: id, result: nil)
        case method
        when "window/workDoneProgress/create"
        # Accept progress token creation
        when "client/registerCapability"
        # Accept capability registration
        else
          # Return empty result for unknown requests
        end
        @io.write_message(response)
      end

      def initialize_server
        request("initialize", {
                  processId: Process.pid,
                  rootUri: @root_uri,
                  rootPath: @root_path,
                  capabilities: client_capabilities,
                  workspaceFolders: [
                    { uri: @root_uri, name: File.basename(@root_path) }
                  ]
                }) do |result, error|
          if error
            @running = false
          else
            @server_capabilities = result&.dig("capabilities") || {}
            notify("initialized", {})
            @initialized = true
          end
          @init_mutex.synchronize { @init_cv.signal }
        end
      end

      def shutdown
        request("shutdown") do |_result, _error|
          notify("exit")
        end
      rescue StandardError
        # Ignore errors during shutdown
      end

      def client_capabilities
        {
          textDocument: {
            hover: {
              contentFormat: %w[plaintext markdown]
            },
            completion: {
              completionItem: {
                snippetSupport: false,
                documentationFormat: %w[plaintext markdown]
              }
            },
            definition: {
              linkSupport: false
            },
            typeDefinition: {
              linkSupport: false
            },
            references: {},
            formatting: {
              dynamicRegistration: false
            },
            publishDiagnostics: {
              relatedInformation: true
            },
            synchronization: {
              didSave: true,
              willSave: false,
              willSaveWaitUntil: false
            }
          },
          workspace: {
            workspaceFolders: true
          }
        }
      end
    end
  end
end
