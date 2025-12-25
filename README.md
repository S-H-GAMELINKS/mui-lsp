# mui-lsp

LSP (Language Server Protocol) plugin for [Mui](https://github.com/S-H-GAMELINKS/mui) editor.

## Features

- **Hover**: Show documentation for symbol under cursor (`K` or `<Space>hf` or `:LspHover`)
- **Go to Definition**: Jump to symbol definition (`<Space>df` or `:LspDefinition`)
- **Find References**: Show all references to symbol (`<Space>rf` or `:LspReferences`)
- **Completion**: Get code completion suggestions (`<Space>cf` or `:LspCompletion`)
- **Format**: Format current file with LSP server (`<Space>ff` or `:LspFormat`)
- **Diagnostics**: Display errors and warnings from LSP server (`:LspDiagnostics`)

## Supported Language Servers

Pre-configured servers for Ruby:

- **Solargraph** - Full-featured Ruby language server
- **ruby-lsp** - Shopify's Ruby language server
- **Kanayago** - Realtime Ruby Syntax Check server
- **RuboCop** (LSP mode) - Ruby linter with LSP support

Custom servers can be configured for other languages.

## Installation

Add to your `.muirc`:

```ruby
# ~/.muirc
Mui.use "mui-lsp"
```

Or if installing from a local path:

```ruby
# ~/.muirc
Mui.use "mui-lsp", path: "/path/to/mui-lsp"
```

## Configuration (Required)

**Important**: mui-lsp does not auto-detect LSP servers. You must explicitly configure which server(s) to use in your `.muirc`.

### Quick Setup

Use the `Mui.lsp` DSL block to configure servers:

```ruby
# ~/.muirc
Mui.use "mui-lsp"

Mui.lsp do
  use :solargraph
end
```

Available pre-configured servers:
- `:solargraph` - Solargraph (full-featured Ruby LSP)
- `:ruby_lsp` - ruby-lsp (Shopify's Ruby LSP)
- `:rubocop` - RuboCop in LSP mode
- `:kanayago` - Kanayago (Japanese Ruby LSP)

### Custom Server Configuration

For other languages or custom setups, use the `server` method:

```ruby
# ~/.muirc
Mui.use "mui-lsp"

Mui.lsp do
  # TypeScript/JavaScript
  server name: "typescript",
         command: "typescript-language-server --stdio",
         language_ids: ["typescript", "javascript"],
         file_patterns: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"]

  # Python (pyright)
  server name: "pyright",
         command: "pyright-langserver --stdio",
         language_ids: ["python"],
         file_patterns: ["**/*.py"]
end
```

### Multiple Servers

You can enable multiple servers for different file types:

```ruby
# ~/.muirc
Mui.use "mui-lsp"

Mui.lsp do
  # Ruby
  use :solargraph

  # TypeScript/JavaScript
  server name: "typescript",
         command: "typescript-language-server --stdio",
         language_ids: ["typescript", "javascript"],
         file_patterns: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"]
end
```

## Usage

### Starting LSP Server

LSP servers are automatically started when you open a file that matches their configured file patterns.

To manually start a server:

```vim
:LspStart solargraph
:LspStart ruby-lsp
:LspStart rubocop
```

### Commands

| Command | Description |
|---------|-------------|
| `:LspStart <name>` | Start a specific LSP server |
| `:LspStop [name]` | Stop a server (all if no name given) |
| `:LspStatus` | Show running and registered servers |
| `:LspHover` | Show hover information |
| `:LspDefinition` | Go to definition |
| `:LspReferences` | Find all references |
| `:LspCompletion` | Show completion menu |
| `:LspDiagnostics` | Show diagnostics for current file |
| `:LspDiagnosticShow` | Show diagnostic at cursor in floating window |
| `:LspFormat` | Format current file |
| `:LspLog` | Show LSP server logs in a buffer |
| `:LspDebug` | Show debug information |
| `:LspOpen` | Manually notify LSP server about current file |

### Keymaps

| Key | Mode | Description |
|-----|------|-------------|
| `K` | Normal | Show hover information (in floating window) |
| `<Space>df` | Normal | Go to definition |
| `<Space>rf` | Normal | Find references |
| `<Space>hf` | Normal | Show hover information (alternative to K) |
| `<Space>cf` | Normal | Show completion |
| `<Space>ef` | Normal | Show diagnostic at cursor (in floating window) |
| `<Space>ff` | Normal | Format current file |
| `Esc` | Normal | Close floating window / picker |

#### Location Picker (for Definition/References with multiple candidates)

When multiple definitions or references are found, a picker buffer opens. Use standard Vim navigation:

| Key | Description |
|-----|-------------|
| `j`/`k` | Navigate up/down (native cursor movement) |
| `\` + `Enter` | Open selected location in current window |
| `Ctrl+t` | Open selected location in new tab |
| `\q` / `\` + `Esc` | Close picker |

## Architecture

```
mui-lsp/
  lib/mui/lsp/
    protocol/          # LSP protocol definitions
      position.rb      # Position (line, character)
      range.rb         # Range (start, end positions)
      location.rb      # Location (URI, range)
      diagnostic.rb    # Diagnostic (error/warning/info)
    handlers/          # Response handlers
      base.rb          # Base handler class
      hover.rb         # Hover response handler
      definition.rb    # Definition response handler
      references.rb    # References response handler
      diagnostics.rb   # Diagnostics notification handler
      completion.rb    # Completion response handler
      formatting.rb    # Formatting response handler
    json_rpc_io.rb     # JSON-RPC 2.0 over stdio
    request_manager.rb # Request ID and callback management
    server_config.rb   # Server configuration presets
    client.rb          # LSP client (manages server process)
    text_document_sync.rb # Document synchronization
    manager.rb         # Multi-server manager
    plugin.rb          # Mui plugin integration
```

## Development

```bash
cd mui-lsp
bundle install
bundle exec rake test
bundle exec rubocop
```

## License

MIT License
