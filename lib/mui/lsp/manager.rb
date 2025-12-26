# frozen_string_literal: true

module Mui
  module Lsp
    # Manages multiple LSP clients and coordinates between editor and servers
    class Manager
      attr_reader :editor, :diagnostics_handler

      def initialize(editor:)
        @editor = editor
        @server_configs = {}
        @clients = {}
        @text_syncs = {}
        @diagnostics_handler = Handlers::Diagnostics.new(editor: editor)
        @mutex = Mutex.new
        @pending_documents = {} # file_path => text, documents waiting for server startup
      end

      def register_server(config)
        @mutex.synchronize do
          @server_configs[config.name] = config
        end
      end

      def start_server(name, root_path = nil)
        config = @mutex.synchronize { @server_configs[name] }
        unless config
          @editor.message = "LSP Error: Unknown server: #{name}"
          return false
        end

        root_path ||= Dir.pwd

        client = Client.new(
          command: config.command,
          root_path: root_path,
          on_notification: method(:handle_notification)
        )

        text_sync = TextDocumentSync.new(
          client: client,
          server_config: config
        )

        client.start

        @mutex.synchronize do
          @clients[name] = client
          @text_syncs[name] = text_sync
        end

        # Check if initialized after a short delay
        @editor.message = if client.initialized
                            "LSP: #{name} ready"
                          else
                            "LSP: #{name} starting..."
                          end
        true
      rescue StandardError => e
        @editor.message = "LSP Error: #{e.message}"
        false
      end

      def stop_server(name)
        client = @mutex.synchronize { @clients.delete(name) }
        text_sync = @mutex.synchronize { @text_syncs.delete(name) }

        return unless client

        text_sync&.close_all
        client.stop
        @editor.message = "LSP server stopped: #{name}"
      end

      def stop_all
        names = @mutex.synchronize { @clients.keys.dup }
        names.each { |name| stop_server(name) }
      end

      def client_for(file_path)
        @mutex.synchronize do
          @server_configs.each do |name, config|
            return @clients[name] if config.handles_file?(file_path) && @clients[name]&.running?
          end
        end
        nil
      end

      def client_for_capability(file_path, capability)
        @mutex.synchronize do
          @server_configs.each do |name, config|
            next unless config.handles_file?(file_path)
            next unless @clients[name]&.running?

            # Check if server supports the capability
            capabilities = @clients[name].server_capabilities
            return @clients[name] if capabilities[capability]
          end
        end
        nil
      end

      def text_sync_for(file_path)
        @mutex.synchronize do
          @server_configs.each do |name, config|
            # Only return text_sync if the client is running
            next unless config.handles_file?(file_path)
            next unless @clients[name]&.running?
            return @text_syncs[name] if @text_syncs[name]
          end
        end
        nil
      end

      def text_syncs_for(file_path)
        result = []
        @mutex.synchronize do
          @server_configs.each do |name, config|
            next unless config.handles_file?(file_path)
            next unless @clients[name]&.running?

            result << @text_syncs[name] if @text_syncs[name]
          end
        end
        result
      end

      def auto_start_for(file_path)
        servers_to_start = []

        @mutex.synchronize do
          @server_configs.each do |name, config|
            next unless config.auto_start && config.handles_file?(file_path)
            next if @clients[name]&.running?

            servers_to_start << [name, find_project_root(file_path)]
          end
        end

        return false if servers_to_start.empty?

        # Start servers in background thread to avoid blocking editor startup
        Thread.new do
          servers_to_start.each do |name, root_path|
            start_server(name, root_path)
            # Send pending documents after server starts
            send_pending_documents(name)
          rescue StandardError => e
            @editor.message = "LSP auto-start error (#{name}): #{e.message}"
          end
        end

        true
      end

      def did_open(file_path:, text:)
        # Store document for servers that are starting up
        @mutex.synchronize do
          @pending_documents[file_path] = text
        end

        auto_start_for(file_path)

        uri = TextDocumentSync.path_to_uri(file_path)
        # Broadcast to all matching servers that are already running
        text_syncs_for(file_path).each do |text_sync|
          text_sync.did_open(uri: uri, text: text)
        end
      end

      def did_change(file_path:, text:)
        uri = TextDocumentSync.path_to_uri(file_path)
        # Broadcast to all matching servers (each text_sync checks sync_on_change)
        text_syncs_for(file_path).each do |text_sync|
          text_sync.did_change(uri: uri, text: text)
        end
      end

      # Sync immediately without debounce (for completion requests)
      def sync_now(file_path:, text:)
        uri = TextDocumentSync.path_to_uri(file_path)
        text_syncs_for(file_path).each do |text_sync|
          text_sync.did_change(uri: uri, text: text, debounce: false, force: true)
        end
      end

      # Force close and re-open document to reset LSP state
      def force_reopen(file_path:, text:)
        uri = TextDocumentSync.path_to_uri(file_path)
        text_syncs_for(file_path).each do |text_sync|
          text_sync.did_close(uri: uri) if text_sync.open?(uri)
          text_sync.did_open(uri: uri, text: text)
        end
      end

      def did_save(file_path:, text: nil)
        uri = TextDocumentSync.path_to_uri(file_path)
        # Broadcast to all matching servers
        text_syncs_for(file_path).each do |text_sync|
          text_sync.did_save(uri: uri, text: text)
        end
      end

      def did_close(file_path:)
        @mutex.synchronize do
          @pending_documents.delete(file_path)
        end

        uri = TextDocumentSync.path_to_uri(file_path)
        # Broadcast to all matching servers
        text_syncs_for(file_path).each do |text_sync|
          text_sync.did_close(uri: uri)
        end
      end

      def hover(file_path:, line:, character:)
        client = client_for(file_path)
        unless client
          @editor.message = server_unavailable_message(file_path)
          return
        end

        uri = TextDocumentSync.path_to_uri(file_path)
        handler = Handlers::Hover.new(editor: @editor, client: client)

        client.hover(uri: uri, line: line, character: character) do |result, error|
          handler.handle(result, error)
        end
      end

      def definition(file_path:, line:, character:)
        text_syncs = text_syncs_for(file_path)
        if text_syncs.empty?
          @editor.message = server_unavailable_message(file_path)
          return
        end

        uri = TextDocumentSync.path_to_uri(file_path)
        handler = Handlers::Definition.new(editor: @editor, client: text_syncs.first.client)

        # Collect results from all clients
        results_mutex = Mutex.new
        pending_count = text_syncs.size
        all_results = []

        text_syncs.each do |text_sync|
          text_sync.client.definition(uri: uri, line: line, character: character) do |result, _error|
            results_mutex.synchronize do
              all_results << result if result
              pending_count -= 1

              if pending_count.zero?
                merged = merge_locations(all_results)
                handler.handle(merged, nil)
              end
            end
          end
        end
      end

      def type_definition(file_path:, line:, character:)
        # Only send to servers that support typeDefinitionProvider
        text_syncs = text_syncs_for(file_path).select do |ts|
          ts.client.server_capabilities["typeDefinitionProvider"]
        end

        if text_syncs.empty?
          # Fallback message: check if any server is running but doesn't support typeDefinition
          any_text_sync = text_syncs_for(file_path).first
          @editor.message = if any_text_sync
                              "LSP: no server supports typeDefinition for this file"
                            else
                              server_unavailable_message(file_path)
                            end
          return
        end

        uri = TextDocumentSync.path_to_uri(file_path)
        handler = Handlers::TypeDefinition.new(editor: @editor, client: text_syncs.first.client)

        # Collect results from all clients
        results_mutex = Mutex.new
        pending_count = text_syncs.size
        all_results = []

        text_syncs.each do |text_sync|
          text_sync.client.type_definition(uri: uri, line: line, character: character) do |result, _error|
            results_mutex.synchronize do
              all_results << result if result
              pending_count -= 1

              if pending_count.zero?
                merged = merge_locations(all_results)
                handler.handle(merged, nil)
              end
            end
          end
        end
      end

      def references(file_path:, line:, character:)
        text_syncs = text_syncs_for(file_path)
        if text_syncs.empty?
          @editor.message = server_unavailable_message(file_path)
          return
        end

        uri = TextDocumentSync.path_to_uri(file_path)
        handler = Handlers::References.new(editor: @editor, client: text_syncs.first.client)

        # Collect results from all clients
        results_mutex = Mutex.new
        pending_count = text_syncs.size
        all_results = []

        text_syncs.each do |text_sync|
          text_sync.client.references(uri: uri, line: line, character: character) do |result, _error|
            results_mutex.synchronize do
              all_results << result if result
              pending_count -= 1

              if pending_count.zero?
                merged = merge_locations(all_results)
                handler.handle(merged, nil)
              end
            end
          end
        end
      end

      def completion(file_path:, line:, character:)
        client = client_for(file_path)
        unless client
          @editor.message = server_unavailable_message(file_path)
          return
        end

        uri = TextDocumentSync.path_to_uri(file_path)
        handler = Handlers::Completion.new(editor: @editor, client: client)

        client.completion(uri: uri, line: line, character: character) do |result, error|
          handler.handle(result, error)
        end
      end

      def format(file_path:, tab_size: 2, insert_spaces: true)
        client = client_for(file_path)
        unless client
          @editor.message = server_unavailable_message(file_path)
          return
        end

        uri = TextDocumentSync.path_to_uri(file_path)
        handler = Handlers::Formatting.new(editor: @editor, client: client)

        client.formatting(uri: uri, tab_size: tab_size, insert_spaces: insert_spaces) do |result, error|
          handler.handle(result, error)
        end
      end

      def jump_to_type_file(file_path:, line: nil, character: nil)
        # For Ruby/RBS files, use custom toggle behavior
        if file_path&.end_with?(".rb", ".rbs")
          jump_to_ruby_type_file(file_path)
        else
          # For other languages, use LSP typeDefinition
          type_definition(file_path: file_path, line: line, character: character)
        end
      end

      private

      def jump_to_ruby_type_file(file_path)
        target_path = if file_path.end_with?(".rb")
                        find_rbs_file(file_path)
                      else
                        find_ruby_file(file_path)
                      end

        unless target_path
          ext = File.extname(file_path)
          target_ext = ext == ".rb" ? ".rbs" : ".rb"
          @editor.message = "No #{target_ext} file found for #{File.basename(file_path)}"
          return
        end

        # Open the target file
        new_buffer = Mui::Buffer.new
        new_buffer.load(target_path)
        @editor.window.buffer = new_buffer
        @editor.message = "Opened #{File.basename(target_path)}"
      end

      public

      def running_servers
        @mutex.synchronize do
          @clients.select { |_, client| client.running? }.keys
        end
      end

      def starting_servers
        @mutex.synchronize do
          @clients.select { |_, client| client.started? && !client.initialized }.keys
        end
      end

      def registered_servers
        @mutex.synchronize { @server_configs.keys }
      end

      def debug_info
        @mutex.synchronize do
          @clients.transform_values do |client|
            {
              started: client.started?,
              initialized: client.initialized,
              last_stderr: client.last_stderr
            }
          end
        end
      end

      def notification_log
        @notification_log ||= []
      end

      private

      def merge_locations(results)
        # Flatten all results into a single array
        merged = results.flat_map do |result|
          case result
          when Array then result
          when Hash then [result]
          else []
          end
        end

        # Remove duplicates based on uri and range
        merged.uniq do |loc|
          uri = loc["uri"] || loc["targetUri"]
          range = loc["range"] || loc["targetSelectionRange"]
          [uri, range]
        end
      end

      def find_rbs_file(ruby_file_path)
        # Find project root
        project_root = find_project_root(ruby_file_path)

        # Get relative path from project root
        abs_path = File.expand_path(ruby_file_path)
        rel_path = abs_path.sub("#{project_root}/", "")

        # Try different RBS path patterns
        candidates = []

        # Pattern 1: sig/relative_path.rbs (e.g., lib/mui/config.rb -> sig/lib/mui/config.rbs)
        candidates << File.join(project_root, "sig", rel_path.sub(/\.rb$/, ".rbs"))

        # Pattern 2: sig/without_lib.rbs (e.g., lib/mui/config.rb -> sig/mui/config.rbs)
        if rel_path.start_with?("lib/")
          candidates << File.join(project_root, "sig", rel_path.sub(%r{^lib/}, "").sub(/\.rb$/, ".rbs"))
        end

        # Pattern 3: sig/basename.rbs (e.g., lib/mui/config.rb -> sig/config.rbs)
        candidates << File.join(project_root, "sig", "#{File.basename(ruby_file_path, ".rb")}.rbs")

        # Return first existing file
        candidates.find { |path| File.exist?(path) }
      end

      def find_ruby_file(rbs_file_path)
        # Find project root
        project_root = find_project_root(rbs_file_path)

        # Get relative path from project root
        abs_path = File.expand_path(rbs_file_path)
        rel_path = abs_path.sub("#{project_root}/", "")

        # Remove sig/ prefix if present
        rel_path = rel_path.sub(%r{^sig/}, "")

        # Try different Ruby path patterns
        candidates = []

        # Pattern 1: lib/relative_path.rb (e.g., sig/mui/config.rbs -> lib/mui/config.rb)
        candidates << File.join(project_root, "lib", rel_path.sub(/\.rbs$/, ".rb"))

        # Pattern 2: relative_path.rb without lib (e.g., sig/lib/mui/config.rbs -> lib/mui/config.rb)
        candidates << File.join(project_root, rel_path.sub(/\.rbs$/, ".rb")) if rel_path.start_with?("lib/")

        # Pattern 3: Search in lib directory for basename
        basename = File.basename(rbs_file_path, ".rbs")
        Dir.glob(File.join(project_root, "lib", "**", "#{basename}.rb")).each do |path|
          candidates << path
        end

        # Return first existing file
        candidates.find { |path| File.exist?(path) }
      end

      def send_pending_documents(server_name)
        text_sync = @mutex.synchronize { @text_syncs[server_name] }
        config = @mutex.synchronize { @server_configs[server_name] }
        return unless text_sync && config

        pending = @mutex.synchronize { @pending_documents.dup }
        pending.each do |file_path, text|
          next unless config.handles_file?(file_path)

          uri = TextDocumentSync.path_to_uri(file_path)
          text_sync.did_open(uri: uri, text: text)
        end
      end

      def server_unavailable_message(file_path)
        # Check if any server is starting (but not yet initialized)
        starting = starting_servers_for(file_path)
        return "LSP: #{starting.join(", ")} still initializing..." unless starting.empty?

        # Check if file type is supported
        supported = @mutex.synchronize do
          @server_configs.select { |_, config| config.handles_file?(file_path) }.keys
        end

        if supported.empty?
          "LSP: no server configured for #{File.basename(file_path)}"
        else
          "LSP: #{supported.join(", ")} not running. Use :LspStart"
        end
      end

      def starting_servers_for(file_path)
        @mutex.synchronize do
          @server_configs.select do |name, config|
            config.handles_file?(file_path) && @clients[name]&.started? && !@clients[name]&.initialized
          end.keys
        end
      end

      def handle_notification(method, params)
        # Log all notifications for debugging
        @notification_log ||= []
        @notification_log << { method: method, params: params, time: Time.now }
        @notification_log.shift if @notification_log.size > 50

        case method
        when "textDocument/publishDiagnostics"
          @diagnostics_handler.handle(params)
        when "window/showMessage"
          handle_show_message(params)
        when "window/logMessage"
          # Ignore log messages for now
        end
      end

      def handle_show_message(params)
        message = params["message"]
        type = params["type"]

        prefix = case type
                 when 1 then "[Error] "
                 when 2 then "[Warning] "
                 when 3 then "[Info] "
                 else ""
                 end

        @editor.message = "#{prefix}#{message}"
      end

      def find_project_root(file_path)
        dir = File.dirname(File.expand_path(file_path))

        # Look for common project markers
        markers = [".git", "Gemfile", "package.json", "Cargo.toml", "go.mod", ".project"]

        while dir != "/"
          markers.each do |marker|
            return dir if File.exist?(File.join(dir, marker))
          end
          dir = File.dirname(dir)
        end

        # Default to the file's directory
        File.dirname(File.expand_path(file_path))
      end
    end
  end
end
