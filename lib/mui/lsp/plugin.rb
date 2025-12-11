# frozen_string_literal: true

require "mui"

module Mui
  module Lsp
    # Main plugin class for mui-lsp
    # Registers commands and keymaps for LSP integration
    class Plugin < Mui::Plugin
      name "lsp"

      def setup
        register_commands
        register_keymaps
        register_autocmds
        setup_default_servers
      end

      private

      def register_commands
        # :LspStart - Start an LSP server
        command(:LspStart) do |ctx, args|
          handle_lsp_start(ctx, args)
        end

        # :LspStop - Stop an LSP server
        command(:LspStop) do |ctx, args|
          handle_lsp_stop(ctx, args)
        end

        # :LspStatus - Show LSP server status
        command(:LspStatus) do |ctx, _args|
          handle_lsp_status(ctx)
        end

        # :LspHover - Show hover information
        command(:LspHover) do |ctx, _args|
          handle_lsp_hover(ctx)
        end

        # :LspDefinition - Go to definition
        command(:LspDefinition) do |ctx, _args|
          handle_lsp_definition(ctx)
        end

        # :LspReferences - Show references
        command(:LspReferences) do |ctx, _args|
          handle_lsp_references(ctx)
        end

        # :LspCompletion - Show completion
        command(:LspCompletion) do |ctx, _args|
          handle_lsp_completion(ctx)
        end

        # :LspDiagnostics - Show diagnostics
        command(:LspDiagnostics) do |ctx, _args|
          handle_lsp_diagnostics(ctx)
        end

        # :LspDiagnosticShow - Show diagnostic at cursor in floating window
        command(:LspDiagnosticShow) do |ctx, _args|
          handle_lsp_diagnostic_show(ctx)
        end

        # :LspDebug - Show debug information
        command(:LspDebug) do |ctx, _args|
          handle_lsp_debug(ctx)
        end

        # :LspLog - Show LSP log in a buffer
        command(:LspLog) do |ctx, _args|
          handle_lsp_log(ctx)
        end

        # :LspOpen - Notify LSP server about current file
        command(:LspOpen) do |ctx, _args|
          handle_lsp_open(ctx)
        end
      end

      def register_keymaps
        # K - Show hover
        keymap(:normal, "K") do |ctx|
          handle_lsp_hover(ctx)
          true
        end

        # Leader key (\) - start pending mode
        keymap(:normal, "\\") do |_ctx|
          @leader_pending = true
          true
        end

        # \d - Go to definition
        keymap(:normal, "d") do |ctx|
          if @leader_pending
            @leader_pending = false
            handle_lsp_definition(ctx)
            true
          else
            false # Let default 'd' handle it
          end
        end

        # \r - Go to references
        keymap(:normal, "r") do |ctx|
          if @leader_pending
            @leader_pending = false
            handle_lsp_references(ctx)
            true
          else
            false # Let default 'r' handle it
          end
        end

        # \h - Show hover (alternative to K)
        keymap(:normal, "h") do |ctx|
          if @leader_pending
            @leader_pending = false
            handle_lsp_hover(ctx)
            true
          else
            false # Let default 'h' handle it
          end
        end

        # \c - Show completion
        keymap(:normal, "c") do |ctx|
          if @leader_pending
            @leader_pending = false
            handle_lsp_completion(ctx)
            true
          else
            false # Let default 'c' handle it
          end
        end

        # \e - Show diagnostic at cursor
        keymap(:normal, "e") do |ctx|
          if @leader_pending
            @leader_pending = false
            handle_lsp_diagnostic_show(ctx)
            true
          else
            false # Let default 'e' handle it
          end
        end

        # Cancel leader pending on any other key (via Escape)
        keymap(:normal, "\e") do |_ctx|
          if @leader_pending
            @leader_pending = false
            true
          else
            false
          end
        end

        # Insert mode: Ctrl+Space - Trigger LSP completion
        keymap(:insert, "\x00") do |ctx|
          handle_lsp_completion(ctx)
          true
        end
      end

      def register_autocmds
        # Hook into buffer open/enter events
        autocmd(:BufEnter) do |ctx|
          file_path = ctx.buffer.file_path
          next unless file_path && !file_path.start_with?("[")

          text = ctx.buffer.lines.join("\n")
          get_manager(ctx.editor).did_open(file_path: file_path, text: text)
        end

        # Hook into text change events
        autocmd(:TextChanged) do |ctx|
          file_path = ctx.buffer.file_path
          next unless file_path && !file_path.start_with?("[")

          text = ctx.buffer.lines.join("\n")
          get_manager(ctx.editor).did_change(file_path: file_path, text: text)
        end

        # Hook into buffer save events
        autocmd(:BufWritePost) do |ctx|
          file_path = ctx.buffer.file_path
          next unless file_path && !file_path.start_with?("[")

          text = ctx.buffer.lines.join("\n")
          get_manager(ctx.editor).did_save(file_path: file_path, text: text)
        end

        # Hook into buffer leave/close events
        autocmd(:BufLeave) do |ctx|
          file_path = ctx.buffer.file_path
          next unless file_path && !file_path.start_with?("[")

          get_manager(ctx.editor).did_close(file_path: file_path)
        end

        # Hook into insert completion trigger (. and @ characters)
        autocmd(:InsertCompletion) do |ctx|
          handle_lsp_completion(ctx)
        end
      end

      def setup_default_servers
        # Load server configs from .muirc DSL (Mui.lsp { use :solargraph })
        @default_server_configs = Mui.lsp_server_configs.dup
      end

      # Command handlers

      def handle_lsp_start(ctx, args)
        server_name = args.to_s.strip
        mgr = get_manager(ctx.editor)
        if server_name.empty?
          ctx.set_message("Usage: :LspStart <server_name>")
          ctx.set_message("Available: #{mgr.registered_servers.join(", ")}")
          return
        end

        begin
          mgr.start_server(server_name)
        rescue StandardError => e
          ctx.set_message("LSP Error: #{e.message}")
        end
      end

      def handle_lsp_stop(ctx, args)
        server_name = args.to_s.strip
        mgr = get_manager(ctx.editor)
        if server_name.empty?
          # Stop all servers
          mgr.stop_all
          ctx.set_message("LSP: all servers stopped")
        else
          mgr.stop_server(server_name)
        end
      end

      def handle_lsp_status(ctx)
        mgr = get_manager(ctx.editor)
        running = mgr.running_servers
        starting = mgr.starting_servers
        registered = mgr.registered_servers

        parts = []
        parts << "running: #{running.join(", ")}" unless running.empty?
        parts << "starting: #{starting.join(", ")}" unless starting.empty?

        if parts.empty?
          ctx.set_message("LSP: no servers running. Registered: #{registered.join(", ")}")
        else
          ctx.set_message("LSP: #{parts.join(", ")} (registered: #{registered.join(", ")})")
        end
      end

      def handle_lsp_hover(ctx)
        file_path = ctx.buffer.file_path
        unless file_path
          ctx.set_message("LSP: no file path")
          return
        end

        line = ctx.window.cursor_row
        character = ctx.window.cursor_col
        get_manager(ctx.editor).hover(file_path: file_path, line: line, character: character)
      end

      def handle_lsp_definition(ctx)
        file_path = ctx.buffer.file_path
        unless file_path
          ctx.set_message("LSP: no file path")
          return
        end

        line = ctx.window.cursor_row
        character = ctx.window.cursor_col
        get_manager(ctx.editor).definition(file_path: file_path, line: line, character: character)
      end

      def handle_lsp_references(ctx)
        file_path = ctx.buffer.file_path
        unless file_path
          ctx.set_message("LSP: no file path")
          return
        end

        line = ctx.window.cursor_row
        character = ctx.window.cursor_col
        get_manager(ctx.editor).references(file_path: file_path, line: line, character: character)
      end

      def handle_lsp_completion(ctx)
        file_path = ctx.buffer.file_path
        unless file_path
          ctx.set_message("LSP: no file path")
          return
        end

        mgr = get_manager(ctx.editor)
        text = ctx.buffer.lines.join("\n")

        # Force re-open document to ensure LSP has latest content
        mgr.force_reopen(file_path: file_path, text: text)

        line = ctx.window.cursor_row
        character = ctx.window.cursor_col
        mgr.completion(file_path: file_path, line: line, character: character)
      end

      def handle_lsp_diagnostics(ctx)
        file_path = ctx.buffer.file_path
        uri = file_path ? TextDocumentSync.path_to_uri(file_path) : nil
        mgr = get_manager(ctx.editor)

        diagnostics = uri ? mgr.diagnostics_handler.diagnostics_for(uri) : []

        if diagnostics.empty?
          ctx.set_message("LSP: no diagnostics")
          return
        end

        ctx.set_message("LSP: #{diagnostics.length} diagnostics")
        diagnostics.first(5).each do |d|
          line = d.range.start.line + 1
          ctx.set_message("  [#{d.severity_name}] Line #{line}: #{d.message}")
        end

        return unless diagnostics.length > 5

        ctx.set_message("  ... and #{diagnostics.length - 5} more")
      end

      def handle_lsp_diagnostic_show(ctx)
        file_path = ctx.buffer.file_path
        uri = file_path ? TextDocumentSync.path_to_uri(file_path) : nil
        mgr = get_manager(ctx.editor)

        return ctx.set_message("LSP: no file") unless uri

        line = ctx.window.cursor_row
        diagnostics = mgr.diagnostics_handler.diagnostics_at_line(uri, line)

        if diagnostics.empty?
          ctx.set_message("LSP: no diagnostic at cursor")
          return
        end

        # Format diagnostics for display
        lines = diagnostics.map do |d|
          "[#{d.severity_name}] #{d.message}"
        end

        # Use floating window if available
        if ctx.editor.respond_to?(:show_floating)
          ctx.editor.show_floating(lines.join("\n\n"), max_height: 10)
        else
          ctx.set_message(lines.first)
        end
      end

      def handle_lsp_debug(ctx)
        mgr = get_manager(ctx.editor)
        info = mgr.debug_info

        if info.empty?
          ctx.set_message("LSP Debug: no clients")
          return
        end

        info.each do |name, data|
          status = if data[:initialized]
                     "ready"
                   elsif data[:started]
                     "starting"
                   else
                     "stopped"
                   end
          ctx.set_message("LSP #{name}: #{status}")
          next unless data[:last_stderr]

          data[:last_stderr].split("\n").each do |line|
            ctx.set_message("  #{line}")
          end
        end
      end

      def handle_lsp_log(ctx)
        mgr = get_manager(ctx.editor)
        info = mgr.debug_info

        lines = ["=== LSP Log ===", ""]

        if info.empty?
          lines << "No LSP clients running."
        else
          info.each do |name, data|
            status = if data[:initialized]
                       "ready"
                     elsif data[:started]
                       "starting"
                     else
                       "stopped"
                     end
            lines << "--- #{name} (#{status}) ---"
            if data[:last_stderr]
              lines.concat(data[:last_stderr].split("\n"))
            else
              lines << "(no stderr output)"
            end
            lines << ""
          end
        end

        # Add notification log
        lines << "=== Notifications ==="
        notifications = mgr.notification_log
        if notifications.empty?
          lines << "(no notifications received)"
        else
          notifications.each do |n|
            lines << "#{n[:time].strftime("%H:%M:%S")} #{n[:method]}"
            if n[:params]
              params_str = n[:params].to_s
              lines << "  #{params_str[0, 200]}#{"..." if params_str.length > 200}"
            end
          end
        end

        ctx.editor.open_scratch_buffer("[LSP Log]", lines.join("\n"))
      end

      def handle_lsp_open(ctx)
        file_path = ctx.buffer.file_path
        unless file_path
          ctx.set_message("LSP: no file path")
          return
        end

        text = ctx.buffer.lines.join("\n")
        mgr = get_manager(ctx.editor)

        # Debug: check if text_sync exists
        text_sync = mgr.text_sync_for(file_path)
        unless text_sync
          ctx.set_message("LSP: no text_sync for #{File.basename(file_path)}")
          return
        end

        mgr.did_open(file_path: file_path, text: text)
        ctx.set_message("LSP: opened #{File.basename(file_path)}")
      end

      public

      def get_manager(editor)
        @managers ||= {}.compare_by_identity
        @managers[editor] ||= create_manager(editor)
      end

      def register_server(config)
        @default_server_configs ||= []
        @default_server_configs << config
      end

      def use_server(name)
        config = case name.to_sym
                 when :solargraph
                   ServerConfig.solargraph(auto_start: true)
                 when :ruby_lsp
                   ServerConfig.ruby_lsp(auto_start: true)
                 when :rubocop
                   ServerConfig.rubocop_lsp(auto_start: true)
                 when :kanayago
                   ServerConfig.kanayago(auto_start: true)
                 else
                   raise ArgumentError, "Unknown server: #{name}. Use :solargraph, :ruby_lsp, :rubocop, or :kanayago"
                 end
        register_server(config)
      end

      private

      def create_manager(editor)
        mgr = Manager.new(editor: editor)
        # Register configured servers
        @default_server_configs&.each do |config|
          mgr.register_server(config)
        end
        mgr
      end
    end
  end
end

# Register the plugin
Mui.plugin_manager.register(:lsp, Mui::Lsp::Plugin)

# DSL for .muirc configuration
# This replaces Mui.lsp stub method from mui core with the real implementation
module Mui
  module Lsp
    # DSL class for configuring LSP in .muirc
    class ConfigDsl
      attr_reader :server_configs

      def initialize(existing_configs = [])
        @server_configs = []
        # Import configs from LspConfigStub if any were defined before gem load
        import_stub_configs(existing_configs)
      end

      def use(name, sync_on_change: nil)
        config = case name.to_sym
                 when :solargraph
                   ServerConfig.solargraph(auto_start: true)
                 when :ruby_lsp
                   # ruby_lsp defaults to sync_on_change: false
                   ServerConfig.ruby_lsp(auto_start: true, sync_on_change: sync_on_change.nil? ? false : sync_on_change)
                 when :rubocop
                   ServerConfig.rubocop_lsp(auto_start: true)
                 when :kanayago
                   ServerConfig.kanayago(auto_start: true)
                 else
                   raise ArgumentError, "Unknown server: #{name}. Use :solargraph, :ruby_lsp, :rubocop, or :kanayago"
                 end
        @server_configs << config
      end

      def server(name:, command:, language_ids:, file_patterns:, auto_start: true, sync_on_change: true)
        @server_configs << ServerConfig.custom(
          name: name,
          command: command,
          language_ids: language_ids,
          file_patterns: file_patterns,
          auto_start: auto_start,
          sync_on_change: sync_on_change
        )
      end

      private

      def import_stub_configs(configs)
        configs.each do |cfg|
          case cfg[:type]
          when :preset
            use(cfg[:name], **cfg.fetch(:options, {}))
          when :custom
            server(
              name: cfg[:name],
              command: cfg[:command],
              language_ids: cfg[:language_ids],
              file_patterns: cfg[:file_patterns],
              auto_start: cfg.fetch(:auto_start, true),
              sync_on_change: cfg.fetch(:sync_on_change, true)
            )
          end
        end
      end
    end
  end

  class << self
    def lsp(&block)
      # Migrate from LspConfigStub to real ConfigDsl on first access after gem load
      if @lsp_config.is_a?(LspConfigStub)
        existing_configs = @lsp_config.server_configs
        @lsp_config = Lsp::ConfigDsl.new(existing_configs)
      end
      @lsp_config ||= Lsp::ConfigDsl.new
      @lsp_config.instance_eval(&block) if block
      @lsp_config
    end

    def lsp_server_configs
      # Ensure migration happens
      lsp unless @lsp_config.is_a?(Lsp::ConfigDsl)
      @lsp_config&.server_configs || []
    end
  end
end
