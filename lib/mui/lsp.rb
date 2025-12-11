# frozen_string_literal: true

require_relative "lsp/version"
require_relative "lsp/protocol"
require_relative "lsp/json_rpc_io"
require_relative "lsp/request_manager"
require_relative "lsp/server_config"
require_relative "lsp/client"
require_relative "lsp/text_document_sync"
require_relative "lsp/handlers"
require_relative "lsp/highlighters/diagnostic_highlighter"
require_relative "lsp/manager"
require_relative "lsp/plugin"

module Mui
  module Lsp
    class Error < StandardError; end
  end
end
