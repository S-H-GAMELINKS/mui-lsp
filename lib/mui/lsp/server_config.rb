# frozen_string_literal: true

module Mui
  module Lsp
    # Configuration for different LSP servers
    class ServerConfig
      attr_reader :name, :command, :language_ids, :file_patterns, :auto_start, :sync_on_change

      def initialize(name:, command:, language_ids:, file_patterns:, auto_start: true, sync_on_change: true)
        @name = name
        @command = command
        @language_ids = Array(language_ids)
        @file_patterns = Array(file_patterns)
        @auto_start = auto_start
        @sync_on_change = sync_on_change
      end

      def handles_file?(file_path)
        @file_patterns.any? do |pattern|
          File.fnmatch?(pattern, file_path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
        end
      end

      def language_id_for(file_path)
        ext = File.extname(file_path).downcase
        case ext
        when ".rb", ".rake", ".gemspec", ".ru"
          "ruby"
        when ".rbs"
          "rbs"
        when ".js"
          "javascript"
        when ".ts"
          "typescript"
        when ".py"
          "python"
        when ".go"
          "go"
        when ".rs"
          "rust"
        when ".c"
          "c"
        when ".cpp", ".cc", ".cxx"
          "cpp"
        when ".java"
          "java"
        else
          @language_ids.first
        end
      end

      def to_h
        {
          name: @name,
          command: @command,
          language_ids: @language_ids,
          file_patterns: @file_patterns,
          auto_start: @auto_start
        }
      end

      class << self
        def solargraph(auto_start: false)
          new(
            name: "solargraph",
            command: "solargraph stdio",
            language_ids: ["ruby"],
            file_patterns: ["**/*.rb", "**/*.rake", "**/Gemfile", "**/Rakefile", "**/*.gemspec"],
            auto_start: auto_start
          )
        end

        def ruby_lsp(auto_start: false, sync_on_change: false)
          new(
            name: "ruby-lsp",
            command: "ruby-lsp",
            language_ids: ["ruby"],
            file_patterns: ["**/*.rb", "**/*.rake", "**/Gemfile", "**/Rakefile", "**/*.gemspec"],
            auto_start: auto_start,
            sync_on_change: sync_on_change
          )
        end

        def kanayago(auto_start: false)
          new(
            name: "kanayago",
            command: "kanayago --lsp",
            language_ids: ["ruby"],
            file_patterns: ["**/*.rb", "**/*.rake", "**/Gemfile", "**/Rakefile", "**/*.gemspec"],
            auto_start: auto_start
          )
        end

        def rubocop_lsp(auto_start: false)
          new(
            name: "rubocop",
            command: "rubocop --lsp",
            language_ids: ["ruby"],
            file_patterns: ["**/*.rb", "**/*.rake", "**/Gemfile", "**/Rakefile", "**/*.gemspec"],
            auto_start: auto_start
          )
        end

        def typeprof(auto_start: false)
          new(
            name: "typeprof",
            command: "typeprof --lsp --stdio",
            language_ids: ["ruby"],
            file_patterns: ["**/*.rb", "**/*.rake", "**/Gemfile", "**/Rakefile", "**/*.gemspec"],
            auto_start: auto_start
          )
        end

        def steep(auto_start: false)
          new(
            name: "steep",
            command: "steep langserver",
            language_ids: %w[ruby rbs],
            file_patterns: ["**/*.rb", "**/*.rbs", "**/*.rake", "**/Gemfile", "**/Rakefile", "**/*.gemspec"],
            auto_start: auto_start
          )
        end

        def custom(name:, command:, language_ids:, file_patterns:, auto_start: true, sync_on_change: true)
          new(
            name: name,
            command: command,
            language_ids: language_ids,
            file_patterns: file_patterns,
            auto_start: auto_start,
            sync_on_change: sync_on_change
          )
        end
      end
    end
  end
end
