## [Unreleased]

## [0.1.0] - 2025-12-11

### Added

- **Core Protocol Support**
  - Position, Range, Location, Diagnostic data types
  - JSON-RPC 2.0 communication layer with Content-Length header framing
  - Request/response callback management

- **LSP Client**
  - Async request/response handling
  - Automatic server initialization
  - Server capability negotiation

- **Text Document Synchronization**
  - didOpen, didChange, didSave, didClose notifications
  - Debounced change notifications (300ms default)
  - Full document sync mode

- **Feature Handlers**
  - Hover: Display documentation for symbol under cursor
  - Definition: Jump to symbol definition
  - References: Find all references to a symbol
  - Completion: Code completion suggestions
  - Diagnostics: Error/warning display with custom highlighter support

- **Pre-configured Servers**
  - Solargraph (`solargraph stdio`)
  - ruby-lsp (`ruby-lsp`)
  - Kanayago (`kanayago`)
  - RuboCop LSP mode (`rubocop --lsp`)

- **Plugin Integration**
  - Commands: `:LspStart`, `:LspStop`, `:LspStatus`, `:LspHover`, `:LspDefinition`, `:LspReferences`, `:LspCompletion`, `:LspDiagnostics`
  - Keymaps: `K` (hover), `gd` (definition), `gr` (references)
  - Buffer hooks for automatic document synchronization
  - Auto-start servers when opening matching files
- Diagnostic underline highlighting:
  - `DiagnosticHighlighter` class for displaying LSP diagnostics with underlines
  - Error (red), warning (yellow), information (blue), and hint (cyan) severity styles
  - Automatic highlight refresh when diagnostics change
  - Requires Mui's dynamic custom highlighter support
- Floating window hover display:
  - Hover information now shown in floating popup window (requires Mui floating window support)
  - Falls back to echo area display for older Mui versions
- `:LspDiagnosticShow` command to display diagnostic at cursor in floating window
- `\e` keymap to show diagnostic at cursor position
- `sync_on_change` option for ServerConfig:
  - Controls whether `didChange` notifications are sent to the server
  - Useful for running multiple LSP servers without conflicts
  - ruby-lsp defaults to `sync_on_change: false`
- Multiple LSP server support:
  - Notifications (didOpen, didChange, didSave, didClose) broadcast to all matching servers
  - Each server can be configured independently with `sync_on_change` option
- Pending document queue for server startup:
  - Documents opened before server is ready are queued
  - Queued documents are sent automatically when server finishes initialization
  - Fixes issue where diagnostics weren't shown for files opened during server startup

